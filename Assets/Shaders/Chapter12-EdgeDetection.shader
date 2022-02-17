Shader "Custom/Chapter12-EdgeDetection"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white" {}
        _EdgeOnly ("Edge Only", Float) = 1.0
        _EdgeColor ("Edge Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _BackgroundColor ("Background Color", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader
    {
        Pass
        {
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            // 声明了一个新的变量 _MainTex_Texe1Size
            // xxx_Texe1Size 是 Unity为我们提供的访问 xxx 纹理对应的每个纹素的大小。
            // 例如，一张 512 X 512 大小的纹理，该值大约为 0.001953 (即1/512) 。由于卷积需要对相邻区域内的纹理进行采样，因此我们需要利用 _MainTex_Texe1Size 来计算各个相邻区域的纹理坐标 。
            half4 _MainTex_TexelSize;
            fixed _EdgeOnly;
            fixed4 _EdgeColor;
            fixed4 _BackgroundColor;

            struct v2f
            {
                float4 pos : SV_POSITION;
                half2 uv[9] : TEXCOORD0;
            };

            v2f vert(appdata_img v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                half2 uv = v.texcoord;

                // 我们在 v2f 结构体中定义了一个维数为 9 的纹理数组，对应了使用 Sobel 算子采样时需要的 9个邻域纹理坐标。
                // 通过把计算采样纹理坐标的代码从片元着色器中转移到顶点着色器中，可以减少运算 ， 提高性能。
                // 由于从顶点着色器到片元着色器的插值是线性的，因此这样的转移并不会影响纹理坐标的计算结果。
                o.uv[0] = uv + _MainTex_TexelSize.xy * half2(-1, -1);
                o.uv[1] = uv + _MainTex_TexelSize.xy * half2(0, -1);
                o.uv[2] = uv + _MainTex_TexelSize.xy * half2(1, -1);
                o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1, 0);
                o.uv[4] = uv + _MainTex_TexelSize.xy * half2(0, 0);
                o.uv[5] = uv + _MainTex_TexelSize.xy * half2(1, 0);
                o.uv[6] = uv + _MainTex_TexelSize.xy * half2(-1, 1);
                o.uv[7] = uv + _MainTex_TexelSize.xy * half2(0, 1);
                o.uv[8] = uv + _MainTex_TexelSize.xy * half2(1, 1);

                return o;
            }

            fixed luminance(fixed4 color)
            {
                return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
            }

            half Sobel(v2f i)
            {
                // 我们首先定义了水平方向和竖直方向使用的卷积核 Gx 和 Gy。接着，我们依次对 9 个像素进行采样，计算它们的亮度值，再与卷积核 Gx 和 Gy 中对应的权重相乘后， 叠加到各自的梯度值上。
                // 最后，我们从1 中减去水平方向和竖直方向的梯度值的绝对值，得到 edge 。
                // edge 值越小，表明该位置越可能是一个边缘点。至此，边缘检测过程结束 。
                const half Gx[9] = {-1, -2, -1,
                                    0, 0, 0,
                                    1, 2, 1};
                const half Gy[9] = {-1, 0, 1,
                                    -2, 0, 2,
                                    -1, 0, 1};
                half texColor;
                half edgeX = 0;
                half edgeY = 0;
                for (int it = 0; it < 9; ++it)
                {
                    texColor = luminance(tex2D(_MainTex, i.uv[it]));
                    edgeX += texColor * Gx[it];
                    edgeY += texColor * Gy[it];
                }

                half edge = 1 - abs(edgeX) - abs(edgeY);

                return edge;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 我们首先调用 Sobel 函数计算当前像素的梯度值 edge ,并利用该值分别计算了背景为原图和纯色下的颜色值 ， 然后利用_EdgeOnly 在两者之间插值得到最终的像素值。 Sobel 函数将利用 Sobel算子对原图进行边缘检测
                half edge = Sobel(i);

                fixed4 withEdgeColor = lerp(_EdgeColor, tex2D(_MainTex, i.uv[4]), edge);
                fixed4 onlyEdgeColor = lerp(_EdgeColor, _BackgroundColor, edge);
                return lerp(withEdgeColor, onlyEdgeColor, _EdgeOnly);
            }

            ENDCG
        }
    }
    Fallback Off
}