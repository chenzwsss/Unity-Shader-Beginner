Shader "Custom/Chapter9-AttenuationAndShadowUseBuildInFunctions"
{
    Properties
    {
        _Diffuse ("Diffuse Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Specular ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Pass
        {
            // 设置渲染路径
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            // #pragma multi_compile_fwdbase 指令可以保证我们在 Shader 中使用光照衰减等光照变量可以被正确赋值。这是不可缺少的
            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Specular;
            fixed4 _Diffuse;
            float _Gloss;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                //  这个宏的作用很简单，就是声明一个用于对阴影纹理采样的坐标。
                // 需要注意的是，这个宏的参数需要是下一个可用的插值寄存器的索引值，在上面的例子中就是 2。
                SHADOW_COORDS(2)
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);

                // Pass shadow coordinates to pixel shader
                // 用于在顶点着色器中计算上一步中声明的阴影纹理坐标
                TRANSFER_SHADOW(o)

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldNormal = normalize(UnityObjectToWorldNormal(i.worldNormal));

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldLight, worldNormal));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + worldLight);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);

                // UNITY_LIGHT_ATTENUATION not only compute attenuation, but also shadow infos
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // UNITY_LIGHT_ATTENUATION 是 Unity 内置的用于计算光照衰减和阴影的宏，我们可以 在内置的 AutoLight.cginc里找到它的相关声明。
                // 它接受 3个参数， 它会将光照衰减和阴影值相乘 后的结果存储到第一个参数中。
                // 注意到，我们并没有在代码中声明第一个参数 atten, 这是因为 UNITY_LIGHT_ATTENUATION 会帮我们声明这个变量。
                // 它的第二个参数是结构体 v2f, 这个 参数会传递给 9.4.2 节中使用的 SHADOW_ATTENUATION, 用来计算阴影值
                // 而第三 个 参数是 世界空间的坐标 ， 正如我们在 9.3 节中看到的 一样 ， 这个参数会用于计算光源空间 下的坐标 ， 再 对光照衰减纹理采样来得到光照衰减。

                return fixed4(ambient + (diffuse + specular) * atten, 1.0);
            }

            ENDCG
        }

        Pass
        {
            // Pass for other pixel lights
            // 设置渲染路径标签
            Tags { "LightMode"="ForwardAdd" }

            // 使用 Blend 命令开启和设置了混合模式
            // 这是因为，我们希望 Additional Pass 计算得到的 光照结果可 以在帧缓存中与之前的光照结果进行叠加
            // 如果没有使用 Blend 命令的话， Additional Pass 会直接覆盖掉之前的光照结果
            // 在本例中 ， 我们选择的混合系数是 Blend One One, 这不是 必需的 ， 我们可以设置成 Unity 支持的任何混合系数。常见的还有 Blend SrcAlpha One
            Blend One One

            CGPROGRAM

            // #pragma multi_compile_fwdbase 指令可以保证我们在 Shader 中使用光照衰减等光照变量可以被正确赋值。这是不可缺少的
            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Specular;
            fixed4 _Diffuse;
            float _Gloss;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                //  这个宏的作用很简单，就是声明一个用于对阴影纹理采样的坐标。
                // 需要注意的是，这个宏的参数需要是下一个可用的插值寄存器的索引值，在上面的例子中就是 2。
                SHADOW_COORDS(2)
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);

                // Pass shadow coordinates to pixel shader
                // 用于在顶点着色器中计算上一步中声明的阴影纹理坐标
                TRANSFER_SHADOW(o)

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldNormal = normalize(UnityObjectToWorldNormal(i.worldNormal));

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldLight, worldNormal));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + worldLight);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);

                // UNITY_LIGHT_ATTENUATION not only compute attenuation, but also shadow infos
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // UNITY_LIGHT_ATTENUATION 是 Unity 内置的用于计算光照衰减和阴影的宏，我们可以 在内置的 AutoLight.cginc里找到它的相关声明。
                // 它接受 3个参数， 它会将光照衰减和阴影值相乘 后的结果存储到第一个参数中。
                // 注意到，我们并没有在代码中声明第一个参数 atten, 这是因为 UNITY_LIGHT_ATTENUATION 会帮我们声明这个变量。
                // 它的第二个参数是结构体 v2f, 这个 参数会传递给 9.4.2 节中使用的 SHADOW_ATTENUATION, 用来计算阴影值
                // 而第三 个 参数是 世界空间的坐标 ， 正如我们在 9.3 节中看到的 一样 ， 这个参数会用于计算光源空间 下的坐标 ， 再 对光照衰减纹理采样来得到光照衰减。

                return fixed4(ambient + (diffuse + specular) * atten, 1.0);
            }

            ENDCG
        }

        // // Pass to render object as a shadow caster
        // Pass
        // {
        //     Name "ShadowCaster"
        //     Tags { "LightMode"="ShadowCaster" }

        //     CGPROGRAM

        //     #pragma vertex vert
        //     #pragma fragment frag
        //     #pragma multi_compile_shadowcaster

        //     #include "UnityCG.cginc"

        //     struct v2f {
        //         V2F_SHADOW_CASTER;
        //     };

        //     v2f vert (appdata_base v)
        //     {
        //         v2f o;
        //         TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
        //         return o;
        //     }

        //     float4 frag(v2f i) : SV_Target
        //     {
        //         SHADOW_CASTER_FRAGMENT(i)
        //     }
        //     ENDCG
        // }
    }
    // 我们这个Shader中只定义了两个Pass，一个Base Pass，一个Additional Pass，并没有定义LightMode为ShadowCaster的Pass
    // 为什么也会产生阴影呢？
    // 是因为内置的 Specular
    // 虽然 Specular 本身也没有包含这 样一个 Pass, 但是由于它的 Fallback 调用了 VertexLit, 它会继续回调，并最终回调到内置的 VertexLit。
    // 我们可以在 Unity 内 置 的着色器里找到它
    // builtin-shaders-xxx->DefaultResourcesExtra->Normal VertexLit.shader 。
    Fallback "Specular"
}