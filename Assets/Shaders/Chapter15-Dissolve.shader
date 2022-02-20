// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Chapter15-Dissolve"
{
    Properties
    {
        // _BurnAmount属性用于控制消融程度 ， 当值为 0 时，物体为正常效果 ， 当值为 1 时， 物体会完全消融
        _BurnAmount ("Burn Amount", Range(0.0, 1.0)) = 0.0
        // _LineWidth属性用于控制模拟烧焦效果时的线宽， 它的值越大， 火焰边缘的蔓延范围 越广
        _LineWidth ("Burn Line Width", Range(0.0, 0.2)) = 0.1
        // _MainTex和_BumpMap分别对应了物体原本的漫反射纹理和法线纹理
        _MainTex ("Main Tex(RGB)", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        // _BurnFirstColor和 _BurnSecondColor 对应了火焰边缘的两种颜色值
        _BurnFirstColor ("Burn First Color", Color) = (1.0, 0.0, 0.0, 1.0)
        _BurnSecondColor ("Burn Second Color", Color) = (1.0, 0.0, 0.0, 1.0)
        // _BurnMap则是关键的噪声纹理
        _BurnMap ("Burn Map", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opqque" "Queue"="Geometry" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            // 我们还使用 Cull 命令关闭了该 Shader 的面片剔除 ， 也就是说 ， 模型的正面和背面都会被渲染
            // 这是因为，消融会导致裸露模型内部的构造，如果只渲染正面会出现错误的结果
            Cull Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            // 为了得到正确的光照，我们设置了 Pass 的 LightMode 和 multi_compile_fwdbase 的编译指令
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            sampler2D _BurnMap;
            float4 _BurnMap_ST;
            float _BurnAmount;
            float _LineWidth;
            fixed4 _BurnFirstColor;
            fixed4 _BurnSecondColor;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uvMainTex : TEXCOORD0;
                float2 uvBumpMap : TEXCOORD1;
                float2 uvBurnMap : TEXCOORD2;
                float3 lightDir : TEXCOORD3;
                float3 worldPos : TEXCOORD4;
                SHADOW_COORDS(5)
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                // 我们使用宏 TRANSFORM_TEX 计算了三张纹理对应的纹理坐标
                o.uvMainTex = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uvBumpMap = TRANSFORM_TEX(v.texcoord, _BumpMap);
                o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);

                // 再把光源方向从模型空间变换到了切线空间
                TANGENT_SPACE_ROTATION;
                o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                // 最后，为了得到阴影信息，计算了世界空间下的顶 点位置和阴影纹理的采样坐标(使用了 TRANSFER_SHADOW 宏)
                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {

                // 首先对噪声纹理进行采样
                fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;
                // 将采样结果和用于控制消融程度的属性 _BurnAmount 相减， 传递给 clip 函数
                // 当结果小于 0 时，该像素将会被剔除，从而不会显示到屏幕上；如果通过了测 试，则进行正常的光照计算
                clip(burn.r - _BurnAmount);

                float3 tangentLightDir = normalize(i.lightDir);
                fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uvBumpMap));

                // 首先根据漫反射纹理得到材质的反射率 albedo, 并由此计算得 到环境光照，进而得到漫反射光照
                fixed3 albedo = tex2D(_MainTex, i.uvMainTex).rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

                // 计算烧焦颜色 burnColor
                // 我们想要在宽度为 _LineWidth 的范围内模拟一个烧焦的颜色变化 ， 第一步就使用了 smoothstep 函数来计算混合系数 t
                // 当 t值为 1 时，表明该像素位于消融的边界处，当 t值为 0 时，表明该像素为正常的模型颜色， 而中间的插值则表示需要模拟一个烧焦效果
                // 首先用 t 来混合两种火焰颜色 _BurnFirstColor 和 _BurnSecondColor, 为了让效果更接近烧焦的痕迹，我们还使用 pow 函数对结果进行处理
                fixed t = 1 - smoothstep(0.0, _LineWidth, burn.r - _BurnAmount);
                fixed3 burnColor = lerp(_BurnFirstColor, _BurnSecondColor, t);
                burnColor = pow(burnColor, 5);

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // 然 后，我们再次使用 t 来混合正常的光照颜色(环境光+漫反射)和烧焦颜色。
                // 我们这里又使用了 step 函数来保证当 _BurnAmount 为 0 时，不显示任何消融效果
                fixed3 finalColor = lerp(ambient + diffuse * atten, burnColor, t * step(0.0001, _BurnAmount));

                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
        Pass
        {
            // 使用透明度测试的物体的阴影需要特别处理，如果仍然使用普通的阴影 Pass, 那么被剔除的区域仍然会向其他物体投射阴影，造成“穿帮”。
            // 为了让物体的阴影也能配合透明度 测试产生正确的效果，我们需要自定义 一个投射阴影 的 Pass

            // 在Unity中，用于投射阴影的Pass的LightMode需要被设置为 ShadowCaster, 
            // 同时，还需要 使用 #pragma multi_compile_shadowcaster 指明它 需要的编译指令
            Tags { "LightMode"="ShadowCaster" }

            // 阴影投射的重点在于我们需要按正常 Pass 的处 理来剔除片元或进行顶点动画 ，以便阴影可以 和物体正常渲染的结果相匹配

            // 在自定义的阴影投射的 Pass 中，我们通常会使用 Unity 提供 的内 置宏 V2F_SHADOW_CASTER，
            // TRANSFER_SHADOW_CASTER_NORMALOFFSET (旧版本中 会使用 TRANSFER_SHADOW_CASTER) 和 SHADOW_CASTER_FRAGMENT 来帮助我们计算 阴影投射时需要的各种变量，而我们可以只关注自定义计算的部分
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_shadowcaster

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _BurnMap;
            float4 _BurnMap_ST;
            float _BurnAmount;

            struct v2f
            {
                // 首先 在 v2f结构体中利用 V2F_SHADOW_CASTER 来定义阴影投射需要定义的变量
                V2F_SHADOW_CASTER;
                float2 uvBurnMap : TEXCOORD1;
            };

            v2f vert(appdata_base v)
            {
                v2f o;

                // 在顶点着色器中，我们使用 TRANSFER_SHADOW_CASTER_NORMALOFFSET 来填充 V2F_SHADOW_CASTER 在背后声明的 一些变量，这是由 Unity 在背后为我们完成的
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o);

                // 我们需要在顶点着色器中 关注自定义的计算部分，这里指的就是我们需要计算噪声纹理的采样坐标 uvBurnMap
                o.uvBurnMap = TRANSFORM_TEX(v.texcoord, _BurnMap);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 在片元着 色器中，我们首先按之前的处理方法使用噪声纹理的采样结果来剔除片元 ， 最后再利用 SHADOW_CASTER_FRAGMENT 来让 Unity 为我们完成阴影投射的部分，把结果输出到深度图 和阴影映射纹理中。
                fixed3 burn = tex2D(_BurnMap, i.uvBurnMap).rgb;

                clip(burn.r - _BurnAmount);

                SHADOW_CASTER_FRAGMENT(i);
            }
            ENDCG
        }
    }
    Fallback Off
}