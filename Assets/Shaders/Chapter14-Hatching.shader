// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Chapter14-Hatching"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // _TileFactor是纹理的平铺系数， _TileFactor越大， 模型上的素描线条越密
        _TileFactor ("Tile Factor", Float) = 1.0
        _Outline ("Outline", Range(0, 1)) = 0.1
        // _HatchO 至 _Hatch5 对应 了渲染 时使用的 6 张素描纹理 ，它们 的线条密度依次增大
        _Hatch0 ("Hatch 0", 2D) = "White" {}
        _Hatch1 ("Hatch 1", 2D) = "White" {}
        _Hatch2 ("Hatch 2", 2D) = "White" {}
        _Hatch3 ("Hatch 3", 2D) = "White" {}
        _Hatch4 ("Hatch 4", 2D) = "White" {}
        _Hatch5 ("Hatch 5", 2D) = "White" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        // 由于素描风格往往也需要在物体周围渲染轮廓线， 因此我们直接使用 14.1 节中渲染轮廓线的 Pass
        // Unity 内部会 把 Pass 的名称全部转成大写格式 ， 所 以我们需要在 UsePass 中使用大写格式的 Pass 名称
        UsePass "Custom/Chapter14-ToonShading/OUTLINE"

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Color;
            float _TileFactor;
            float _Outline;
            sampler2D _Hatch0;
            sampler2D _Hatch1;
            sampler2D _Hatch2;
            sampler2D _Hatch3;
            sampler2D _Hatch4;
            sampler2D _Hatch5;

            struct a2v
            {
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            // 由于我们需要在顶点着色器中计算 6 张纹理的混合权重， 我们首先需要在 v2f结构体中添加相应的变量
            // 由于一共声明了 6 张纹理，这意味着需要 6 个混 合权重，我们把它们存储在两个 fixed3 类型 的变量(hatchWeights0 和 hatchWeights1)中。
            // 为了添加阴影效果，我们还声明了 worldPos 变量， 并使用 SHADOW_COORDS 宏声明了阴影纹理的采样坐标。
            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed3 hatchWeights0 : TEXCOORD1;
                fixed3 hatchWeights1 : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert (a2v v)
            {
                v2f o;
                // 我们首先对顶点进行了基本的坐标变换
                o.pos = UnityObjectToClipPos(v.vertex);
                // 然后，使用_TileFactor 得到了纹理采样坐标
                o.uv = v.texcoord.xy * _TileFactor;

                // 在计 算 6 张纹理的混合权重之前，我们首先需要计算逐顶点光照

                // 因此 ，我们 使用世界空间下的光照 方向和法线方向得到漫反射系数 diff。
                // 之后 ，我们把权重值初始化为 0, 并把 diff 缩放到 [O, 7]范围， 得到 hatchFactor。
                // 我们把 [O, 7]的 区间均匀划分为 7 个 子区间 ，通过判断 hatchFactor 所处的子 区间 来计算对应的纹理混合权重。
                // 最后，我们计算了顶点的世界坐标，并使用 TRANSFER_SHADOW 宏来计算阴影纹理的采样坐标。
                fixed3 worldLightDir = normalize(WorldSpaceLightDir(v.vertex));
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed diff = max(0, dot(worldLightDir, worldNormal));

                o.hatchWeights0 = fixed3(0.0, 0.0, 0.0);
                o.hatchWeights1 = fixed3(0.0, 0.0, 0.0);

                float hatchFactor = diff * 7.0;

                if (hatchFactor > 6.0)
                {
                    // Pure white, do nothing
                }
                else if (hatchFactor > 5.0)
                {
                    o.hatchWeights0.x = hatchFactor - 5.0;
                }
                else if (hatchFactor > 4.0)
                {
                    o.hatchWeights0.x = hatchFactor - 4.0;
                    o.hatchWeights0.y = 1.0 - o.hatchWeights0.x;
                }
                else if (hatchFactor > 3.0)
                {
                    o.hatchWeights0.y = hatchFactor - 3.0;
                    o.hatchWeights0.z = 1.0 - o.hatchWeights0.y;
                }
                else if (hatchFactor > 2.0)
                {
                    o.hatchWeights0.z = hatchFactor - 2.0;
                    o.hatchWeights1.x = 1.0 - o.hatchWeights0.z;
                }
                else if (hatchFactor > 1.0)
                {
                    o.hatchWeights1.x = hatchFactor - 1.0;
                    o.hatchWeights1.y = 1.0 - o.hatchWeights1.x;
                }
                else
                {
                    o.hatchWeights1.y = hatchFactor;
                    o.hatchWeights1.z= 1.0 - o.hatchWeights1.y;
                }

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 当得到了 6 六张纹理的混合权重后 ，我们对每张纹理进行采样并和它们对应的权重值相乘得到 每张纹理的采样颜色
                fixed4 hatchTex0 = tex2D(_Hatch0, i.uv) * i.hatchWeights0.x;
                fixed4 hatchTex1 = tex2D(_Hatch1, i.uv) * i.hatchWeights0.y;
                fixed4 hatchTex2 = tex2D(_Hatch2, i.uv) * i.hatchWeights0.z;
                fixed4 hatchTex3 = tex2D(_Hatch3, i.uv) * i.hatchWeights1.x;
                fixed4 hatchTex4 = tex2D(_Hatch4, i.uv) * i.hatchWeights1.y;
                fixed4 hatchTex5 = tex2D(_Hatch5, i.uv) * i.hatchWeights1.z;

                // 我们还计算了纯白在渲染中的贡献度 ，这是通过从 1 中减去所有 6 张纹理的 权重来得到的。这是因为素描中往往有留白的部分，因此我们希望在最后的渲染中光照最亮的部分 是纯白色的。
                fixed4 whiteColor = fixed4(1.0, 1.0, 1.0, 1.0) * (1 - i.hatchWeights0.x - i.hatchWeights0.y - i.hatchWeights0.z - i.hatchWeights1.x - i.hatchWeights1.y - i.hatchWeights1.z);

                fixed4 hatchColor = hatchTex0 + hatchTex1 + hatchTex2 + hatchTex3 + hatchTex4 + hatchTex5 + whiteColor;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                return fixed4(hatchColor.rgb * _Color.rgb * atten, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}