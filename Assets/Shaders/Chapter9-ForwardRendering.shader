// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

Shader "Custom/Chapter9-ForwardRendering"
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
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);

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

                // 然后， 我们在 Base Pass 中处理了场景中的最重要的平行光。在这个例子中， 场景中只有 一个平行光。
                // 如果场景中包含了多个平行光， Unity 会选择最亮的平行光传递给 Base Pass 进行逐 像素处理， 其他平行光会按照逐顶点或在 Additional Pass 中按逐像素的方式处理。
                // 如果场景中没 有任何平行光， 那么 Base Pass 会当成全黑的光源处理。
                // 我们提到过， 每一个光源有 5 个属性:位 置、 方向、 颜色、 强度以及衰减。 对于 Base Pass 来说， 它处理的逐像素光源类型一定是平行光。
                // 我们可以使用 _WorldSpaceLightPos0 来得到这个平行光的方向(位置对平行光来说没有意义)， 使用 _LightColor0 来得到它的颜色和强度 (_LightColor0 已经是颜色和强度相乘后的结果)

                // 由于 平行光可以认为是没有衰减的， 因此这里我们直接令衰减值为 1.0
                fixed atten = 1.0;

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

            // 这个指令可 以保证我们在 Additional Pass 中访问到正确的光照变量
            #pragma multi_compile_fwdadd

            // 通常来说， Additional Pass的光照处理和 BasePass 的处理方式是一样的， 因此我们只需要把 BasePass 的顶点和片元蓿色器代码粘贴到 Additional Pass中， 然后再稍微修改一下即可。
            // 这些修改往往是 为 了去掉 Base Pass 中环境光 、 自发光 、 逐顶点光照 、 SH 光照的部分 ， 并添加 一些对不同光源类型的支持。
            // 因此，在 Additional Pass 的片元着色器中 ， 我们没有再计算场景中的环境光。
            // 由于 Additional Pass 处理的光源类型可能是平行光、点光源或是聚光灯 ， 因此在计算光源的5个属性一位置、 方向、颜色、强度以及衰减时，颜色和强度我们仍然可以使用_LightColorO来得到，
            // 但对于位置 、 方向和衰减属性 ， 我们就需要根据光源类型分别计算。具体计算看下面片元着色器内的代码

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "UnityDeferredLibrary.cginc"

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
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 如果当前前向渲染 Pass 处理的光源 类型是平行光 ， 那么 Unity 的底层渲染 引 擎就会定 义 USING_DIRECTIONAL_LIGHT
                // 如果判断 得知是平行光 的话 ， 光源方向 可 以直接由 _WorldSpaceLightPos0.xyz 得 到;
                // 如果是点光源或聚光灯，那么 _WorldSpaceLightPos0.xyz表示 的是世界空间下 的光源位置 ， 而想要得到光源方向的话 ， 我们就需要用这个位置减去世界空间下的顶点位置。
                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                #else
                    fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                #endif

                // fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));

                fixed3 worldNormal = normalize(UnityObjectToWorldNormal(i.worldNormal));

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldLight, worldNormal));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + worldLight);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);

                // 如果是平行光的话， 衰减值为 1.0
                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed atten = 1.0;
                // 如果是其他光源类型， 那么处理更复杂一些。尽管我们可以使 用数学表达式来计算给定点相对于点光源和聚光灯的衰减 ， 但这些计算往往涉及开根号、除法等计算量相对较大的操作
                // 因此 Unity 选择了使用一张纹理作为查找表 (Lookup Table, LUT), 以 在片元着色器中得到光源的衰减。 我们首先得到光源空间下的坐标，然后使用该坐标对衰减纹理 进行采样得到衰减值。
                // 关于 Unity 中衰减纹理的细节可以参见 9.3 节。
                #else
                    float3 lightCoord = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
                    fixed atten = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).UNITY_ATTEN_CHANNEL;
                #endif

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