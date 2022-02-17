Shader "Custom/Chapter12-GaussianBlur"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white" {}
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        // 在本节中 ，我们将第一次使用 CGINCLUDE 来组织代码。我们在SubShader 块中 利用CGINCLUDE 和 ENDCG 语义来定义一系列代码
        // 这些代码不需要包含在任何 Pass 语义块中 ， 在使用时 ，我们只需要在 Pass 中直接指定需要使用的顶点着色器和片元着色器函数名即可
        // CGINCLUDE 类似于 C++中头文件的功能
        // 由于高斯模糊需要定义两个 Pass , 但它们使用的片元着色器代码是完全相同的 ， 使用 CGINCLUDE 可以避免我们编写两个完全一样的 frag 函数
        CGINCLUDE
            sampler2D _MainTex;
            half4 _MainTex_TexelSize;
            float _BlurSize;

            #include "UnityCG.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                half2 uv[5] : TEXCOORD0;
            };

            // 在本节中我们会利用 5 x 5 大小的高斯核对原图像进行高斯模糊 ， 而由12.4.1 节可知，一个 5 x 5的二维高斯核可以拆分成两个大小为 5 的一维高斯核 ，因此我们只需要计算 5 个纹理坐标即可
            // 为此，我们在 v2f 结构体中定义了 一个 5 维的纹理坐标数组
            // 数组的第一个坐标存储了当前的采样纹理，而剩余的四个坐标则是高斯模糊中对邻域采样时使用的纹理坐标
            // 我们还和属性 _BlurSize 相乘来控制采样距离。在高斯核维数不变的情况下，_BlurSize 越大，模糊程度越高 ， 但采样数却不会受到影响。但过大的 _BlurSize 值会造成虚影，这可能并不是我们希望的。
            // 通过把计算采样纹理坐标的代码从片元着色器中转移到顶点壮色器中，可以减少运算，提高性能。由于从顶点若色器到片元右色器的插值是线性的，因此这样的转移并不会影响纹理坐标的计算结果。

            v2f vertBlurVertical(appdata_img v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                half2 uv = v.texcoord;

                o.uv[0] = uv;
                o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
                o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.y * 1.0) * _BlurSize;
                o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;
                o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.y * 2.0) * _BlurSize;

                return o;
            }

            // 水平方向的顶点着色器和上面的代码类似， 只是在计算4个纹理坐标时使用了水平方向的纹素大小进行纹理偏移。
            v2f vertBlurHorizontal(appdata_img v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                half2 uv = v.texcoord;

                o.uv[0] = uv;
                o.uv[1] = uv + float2(0.0, _MainTex_TexelSize.x * 1.0) * _BlurSize;
                o.uv[2] = uv - float2(0.0, _MainTex_TexelSize.x * 1.0) * _BlurSize;
                o.uv[3] = uv + float2(0.0, _MainTex_TexelSize.x * 2.0) * _BlurSize;
                o.uv[4] = uv - float2(0.0, _MainTex_TexelSize.x * 2.0) * _BlurSize;

                return o;
            }

            // 由 12.4.1 节可知， 一个 5x5 的二维高斯核可以拆分成两个大小为 5 的一维高斯核， 并且由于它的对称性，我们只需要记录 3 个高斯权重， 也就是代码中的 weight 变量。
            fixed4 fragBlur(v2f i) : SV_Target
            {
                // 我们首先声明了各个邻域像素对应的权重 weight, 然后将结果值 sum 初始化为当前的像素值乘以它的权重值。
                float weight[3] = {0.4026, 0.2442, 0.0545};
                fixed3 sum = tex2D(_MainTex, i.uv[0]).rgb * weight[0];
                // 根据对称性， 我们进行了两次迭代， 每次迭代包含了两次纹理采样， 并把像素值和权重相乘后的结果叠加到 sum 中。 最后， 函数返回滤波结果 sum。
                for (int it = 1; it < 3; it++) {
                    sum += tex2D(_MainTex, i.uv[it*2-1]).rgb * weight[it];
                    sum += tex2D(_MainTex, i.uv[it*2]).rgb * weight[it];
                }

                return fixed4(sum, 1.0);
            }
        ENDCG

        // 注意， 我们仍然首先设置了渲染状态。 和之前实现不同的是， 我们为两个 Pass 使用 NAME 语义（见 3.3.3 节） 定义了它们的名字。
        // 这是因为， 高斯模糊是非常常见的图像处理操作， 很多屏幕特效都是建立在它的基础上的， 例如 Bloom 效果（见 12.5 节）。 为 Pass 定义名字， 可以在其他 Shader 中直接通过它们的名字来使用该 Pass, 而不需要再重复编写代码。
        Pass
        {
            NAME "GAUSSIAN_BLUR_VERTICAL"

            CGPROGRAM

            #pragma vertex vertBlurVertical
            #pragma fragment fragBlur

            ENDCG
        }

        Pass
        {
            NAME "GAUSSIAN_BLUR_HORIZONTAL"

            CGPROGRAM

            #pragma vertex vertBlurHorizontal
            #pragma fragment fragBlur

            ENDCG
        }
    }
    Fallback Off
}