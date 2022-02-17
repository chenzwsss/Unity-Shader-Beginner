Shader "Custom/Chapter12-Bloom"
{
    Properties
    {
        // _MainTex 对应了输入的渲染纹理
        _MainTex ("Main Tex(RGB)", 2D) = "white" {}
        // _Bloom 是高斯模糊后的较亮区域
        _Bloom ("Bloom(RGB)", 2D) = "black" {}
        // _LuminanceThreshold 是用于提取较亮区域使用的阙值
        _LuminanceThreshold ("Luminance Threshold", Float) = 0.5
        // 而_BlurSize和 12.4节中的作用相同，用于控制不同迭代之间高 斯模糊的模糊区域范围
        _BlurSize ("Blur Size", Float) = 1.0
    }
    SubShader
    {
        CGINCLUDE

        sampler2D _MainTex;
        half4 _MainTex_TexelSize;
        sampler2D _Bloom;
        float _LuminanceThreshold;
        float _BlurSize;

        #include "UnityCG.cginc"

        struct v2f
        {
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
        };

        v2f vertExtractBright(appdata_img v)
        {
            v2f o;

            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv = v.texcoord;

            return o;
        }

        fixed luminance(fixed4 color)
        {
            return 0.2125 * color.r + 0.7154 * color.g + 0.0721 * color.b;
        }

        fixed4 fragExtractBright(v2f i) : SV_Target
        {
            fixed4 c = tex2D(_MainTex, i.uv);
            // 在片元着色器中，我们将采样得到的亮度值减去阐值 _LuminanceThreshold, 并把结果截取到 0-1 范围内
            fixed val = clamp(luminance(c) - _LuminanceThreshold, 0.0, 1.0);
            // 然后，我们把该值和原像素值相乘，得到提取后的亮部区域
            return c * val;
        }

        struct v2fBloom
        {
            float4 pos : SV_POSITION;
            half4 uv : TEXCOORD0;
        };

        v2fBloom vertBloom(appdata_img v)
        {
            v2fBloom o;

            o.pos = UnityObjectToClipPos(v.vertex);
            // 这里使用的顶点着色器与之前的有所不同，我们定义了两个纹理坐标，并存储在同一个类型为 half4 的变量 uv 中。
            // 它的 xy 分量对应了_MainTex, 即原图像的纹理坐标。而它的 zw 分量是 _Bloom, 即模糊 后的较亮区域的纹理坐标。
            o.uv.xy = v.texcoord;
            o.uv.zw = v.texcoord;
            // 我们需要对_Bloom的纹理坐标进行平台差异化处理(详见 5.6.1 节)。
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0.0)
                o.uv.w = 1.0 - o.uv.w;
            #endif

            return o;
        }

        fixed4 fragBloom(v2fBloom i) : SV_Target
        {
            return tex2D(_MainTex, i.uv.xy) + tex2D(_Bloom, i.uv.zw);
        }
        ENDCG

        ZTest Always Cull Off ZWrite Off

        Pass
        {
            CGPROGRAM

            #pragma vertex vertExtractBright
            #pragma fragment fragExtractBright

            ENDCG
        }

        UsePass "Custom/Chapter12-GaussianBlur/GAUSSIAN_BLUR_VERTICAL"

        UsePass "Custom/Chapter12-GaussianBlur/GAUSSIAN_BLUR_HORIZONTAL"

        Pass
        {
            CGPROGRAM

            #pragma vertex vertBloom
            #pragma fragment fragBloom

            ENDCG
        }
    }
    Fallback Off
}