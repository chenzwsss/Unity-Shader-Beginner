// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/Chapter14-ToonShading"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex ("Main Tex", 2D) = "white" {}
        // _Ramp是用于控制漫反射色调的渐变纹理
        _Ramp ("Ramp Texture", 2D) = "white" {}
        // _Outline用于控制轮廓线宽度
        _Outline ("Outline", Range(0, 1)) = 0.1
        // OutlineColor 对应了轮廓线颜色
        _OutlineColor ("Outline Color", Color) = (0.0, 0.0, 0.0, 1.0)
        // _Specular 是高光反射颜色
        _Specular ("Specular", Color) = (1.0, 1.0, 1.0, 1.0)
        // _SpecularScale 用于控制计算高光反射时使用的阈值
        _SpecularScale ("Specular Scale", Range(0, 0.1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}
        Pass
        {
            // 值得注意的是，我们还使用 NAME 命令为该 Pass 定义了名称。
            // 这是因为，描边在非真实感渲染中是非常常见的效果，为该 Pass 定义名称可以让我们在后面的使用中不需要再重复编写此 Pass，而只需要调用它的名字即可
            NAME "OUTLINE"

            // 我们使用 Cull指令把正面的三角面片剔除，而只渲染背面
            Cull Front

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            float _Outline;
            fixed4 _OutlineColor;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };

            v2f vert(a2v v)
            {
                v2f o;

                // 在顶点着色器中我们首先把顶点和法线变换到视角空间下，这是为了让描边可以在观察空间达到最好的效果
                float4 pos = mul(UNITY_MATRIX_MV, v.vertex);
                float3 normal = mul((float3x3)UNITY_MATRIX_IT_MV, v.normal);
                // 随后 ， 我们设置法线的 z 分量 ， 对其归一化后再将顶点沿其 方向扩张 ， 得到扩张后的顶点坐标
                // 对法线的处理是为了尽可能避免背面扩张后的顶点挡住正面 的面片
                normal.z = -0.5;
                pos = pos + float4(normalize(normal), 0) * _Outline;
                // 最后 ， 我们把顶点从视角空间变换到裁剪空间
                o.pos = mul(UNITY_MATRIX_P, pos);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 片元着色器的代码非常简单，我们只需要用轮廓线颜色渲染整个背面即可
                return fixed4(_OutlineColor.rgb, 1);
            }

            ENDCG
        }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            Cull Back

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityShaderVariables.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _Ramp;
            float4 _Ramp_ST;
            fixed4 _Specular;
            float _SpecularScale;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
                float4 tangent : TANGENT;
            }; 

            struct v2f
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                SHADOW_COORDS(3)
            };

            v2f vert(a2v v)
            {
                v2f o;

                // 计算世界空间下的法线方向和顶点位置，并使用 Unity 提供的 内置 宏 SHADOW_COORDS 和 TRANSFER_SHADOW 来计算阴影所需的各个变量
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                //  首先 ， 我们计算了光照模型中需要的各个方向矢量 ， 并对它们进行了归一化处理
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 worldHalfDir = normalize(worldLightDir + worldViewDir);
                // 然后 ， 我 们计算了材质的反射率 albedo 和环境光照 ambient
                fixed4 c = tex2D(_MainTex, i.uv);
                fixed3 albedo = c.rgb * _Color.rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;
                // 接着 ， 我 们 使用内置的 UNITY_LIGHT_ATTENUATION 宏来计算当前世界坐标下的阴影值
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
                // 随后，我们计算了半兰伯特漫反射系数 ， 并 和阴影值相乘得到最终的漫反射系数
                fixed diff = dot(worldNormal, worldLightDir);
                diff = (diff * 0.5 + 0.5) * atten;
                // 我们使用这个漫反射系数对渐变纹理 _Ramp 进行采样，并 将结果和材质的反射率、光照颜色相乘， 作为最后的漫反射光照
                fixed3 diffuse = _LightColor0.rgb * albedo * tex2D(_Ramp, float2(diff, diff)).rgb;

                // 高光反射的计算和 14.1.2节中 介绍的方法一致 ， 我们使用 fwidth 对高光区域的边界进行抗锯齿处理 ， 并将计算而得的高光反射 系数和高光反射颜色相乘，得到高光反射的光照部分
                fixed spec = dot(worldNormal, worldHalfDir);
                fixed w = fwidth(spec) * 2.0;
                // 值得注意的是，我们在最后还使用了 step(0.000 1, _SpecularScale), 这是为了在 _SpecularScale 为 0 时 ， 可以完全消除高光反射的光照。 最后，返回环境光照、漫反射光照和高光反射光照叠加的结果。
                fixed3 specular = _Specular.rgb * lerp(0, 1, smoothstep(-w, w, spec + _SpecularScale - 1)) * step(0.0001, _SpecularScale);

                return fixed4(ambient + diffuse + specular, 1.0);
            }

            ENDCG
        }
    }
    Fallback "Diffuse"
}