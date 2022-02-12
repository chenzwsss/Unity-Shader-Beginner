Shader "Custom/Chapter8-AlphaTestBothSided"
{
    Properties
    {
        _Color ("Main Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex ("Main Tex", 2D) = "white" {}
        // _Cutoff参数用于决定我们调用 clip 进行透明度测试时使用的判断条件 。 它的范围是 [O, 1], 这是因为纹理像素的透明度就是在此范围内。
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
    }
    SubShader
    {
        // 我们在 8.2 节中已经知道渲染顺序的重要性，并且知道在 Unity 中透明度测试使用的渲染队 列是名为 AlphaTest 的队列，因此我们 需要把 Queue 标签设置为 AlphaTest。
        // 而 RenderType 标签可以让 Unity把这个 Shader 归入到提前定义的组(这里就是 TransparentCutout组)中，以指明该 Shader 是一个使用了透明度测试的 Shader。
        // RenderType 标签通常被用于着色器替换功能。
        // 我们还把 IgnoreProjector 设置为 True, 这意味着这个 Shader不会受到投影器 (Projectors) 的影响。
        // 通常， 使用了透明度测试的 Shader 都应该在 SubShader 中设置这三个标签。
        Tags { "Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout" }
        Pass
        {
            // LightMode 标签是 Pass 标签中的一种，它用于定义该 Pass在 Unity 的光照流水线中的角色。只有定义了正确的 LightMode, 我们才能正确得到一些 Unity 的内置光照变瓜，例如_LightColor0。
            Tags { "LightMode"="ForwardBase" }

            // Turn off culling
            // 关闭剔除功能
            Cull Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            // 由于_Cutoff的范围在[O, 1], 因此我们可以使用 fixed 精度来存储它。
            fixed _Cutoff;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);

                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));

                fixed4 texColor = tex2D(_MainTex, i.uv);

                // Alpha test
                // clip 函数的定义，它会判断它的参数，即 texColor.a - _ Cutoff 是否为负 数，如果是就会舍弃该片元的输出。
                // 也就是说，当 texColor.a 小于材质参数_Cutoff时，该片元就 会产生完全透明的效果。
                // 使用 clip 函数等同于先判断参数是否小于零，如果是就使用 discard 指令 来显式剔除该片元，后面的代码和之前使用过的完全一样
                clip(texColor.a - _Cutoff);
                // Equal to
                // if ((texColor.a - _Cutoff) < 0.0)
                // {
                //     discard;
                // }

                fixed3 albedo = texColor.rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(worldNormal, worldLight));

                return fixed4(ambient + diffuse, 1.0);
            }

            ENDCG
        }
    }
    // 这次我们使用内置的 Transparent/Cutout/VertexLit 来 作为回调 Shader。
    // 这不仅能够保证在我们编写的 SubShader无法在当前显卡上工作时可以有合适 的代替 Shader,
    // 还可以保证使用透明度测试的物体可以正确地向其他物体投射阴影，具体原理可以 参 见 9.4.5 节 。
    Fallback "Transparent/Cutout/VertexLit"
}