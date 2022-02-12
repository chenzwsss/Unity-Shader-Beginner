Shader "Custom/Chapter8-AlphaBlend"
{
    Properties
    {
        _Color ("Main Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex ("Main Tex", 2D) = "white" {}
        // AlphaScale 用 于在透明纹理的基础上控制整体的透明度。
        _AlphaScale ("Alpha Scale", Range(0, 1)) = 1
    }
    SubShader
    {
        // Unity 中透明度混合使用的渲染队列是名为 Transparent 的队 列，因此我们需要把 Queue标签设置为 Transparent。
        // RenderType标签可以让 Unity 把这个 Shader 归入到提前定义的组(这里就是 Transparent组)中，用来指明该 Shader是一个使用了透明度混合 的 Shader。RenderType 标签通常被用于着色器替换功能。
        // 我们还把 IgnoreProjector 设置为 True, 这意味着这个 Shader 不会受到投影器 (Projectors) 的影响。
        // 通常，使用了透明度混合的 Shader 都应该在 SubShader 中设置这 3 个标签。
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
        Pass
        {
            // LightMode 标签是 Pass 标签中的一种，它用于定义该 Pass在 Unity 的光照流水线中的角色。只有定义了正确的 LightMode, 我们才能正确得到一些 Unity 的内置光照变瓜，例如_LightColor0。
            Tags { "LightMode"="ForwardBase" }

            // 该 Pass 的深度写入 (ZWrite) 设置为关闭状态 (Off),
            ZWrite Off
            // 开启并设置了该 Pass 的混合模式
            // 将源颜色(该片元着色器产生的颜 色)的混合因子设为 SrcAlpha, 把目标颜色(已经存在于颜色缓冲中的颜色)的混合因子设为 OneMinusSrcAlpha, 以得到 合适的半透明效果。
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            // 由于_Cutoff的范围在[O, 1], 因此我们可以使用 fixed 精度来存储它。
            fixed _AlphaScale;

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

                fixed3 albedo = texColor.rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(worldNormal, worldLight));

                // 设置了该片元着色 器返回值中的透明通道 ， 它是纹理像素的透明通道和 材质参数_AlphaScale 的乘积。
                // 只有使用 Blend 命令打开混合后 ， 我们在这里设置透明通道才有意义 ， 否则 ， 这些透 明度并不会对片元 的透明效果有任何影响。
                return fixed4(ambient + diffuse, texColor.a * _AlphaScale);
            }

            ENDCG
        }
    }
    Fallback "Transparent/Cutout/VertexLit"
}