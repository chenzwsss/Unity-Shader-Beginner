Shader "Custom/Chapter12-MotionBlur"
{
    Properties
    {
        // _MainTex 对应了输入的渲染纹理
        _MainTex ("Main Tex(RGB)", 2D) = "white" {}
        // _BlurAmount 是混合图像时使用的混合系数
        _BlurAmount ("Blur Amount", Float) = 1.0
    }
    SubShader
    {
        CGINCLUDE

        #include "UnityCG.cginc"

        sampler2D _MainTex;
        fixed _BlurAmount;

        struct v2f
        {
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
        };

        v2f vert(appdata_img v)
        {
            v2f o;

            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv = v.texcoord;

            return o;
        }

        // 我们定义了两个片元着色器， 一个用于更新渲染纹理的 RGB 通道部分， 第一个 用于更新渲染纹理的 A 通道部分

        // RGB 通道版本的 Shader 对当前图像进行采样，并将其 A 通道的值设为_BlurAmount, 以便在后 面混合时可以使用它的透明通道进行混合。
        fixed4 fragRGB(v2f i) : SV_Target
        {
            return fixed4(tex2D(_MainTex, i.uv).rgb, _BlurAmount);
        }

        // A 通道版本的代码就更简单了， 直接返回采样结果
        // 实 际上， 这个版本只是为了维护渲染纹理的透明通道值， 不让其受到混合时使用的透明度值的影响
        half4 fragA(v2f i) : SV_Target
        {
            return tex2D(_MainTex, i.uv);
        }

        ENDCG

        // 然后， 我们定义了运动模 糊所需的 Pass
        ZTest Always Cull Off ZWrite Off

        // 一个用于更新渲 染纹理的 RGB 通道
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            
            ColorMask RGB

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragRGB

            ENDCG
        }

        // 另一个用于更新 A 通道

        // 之所以要把 A 通道和 RGB 通道分开， 是因为在 更新 RGB 时我们需要设置它的 A 通道来混合图像， 但又不希望 A 通道的值写入渲染纹理中
        Pass
        {
            Blend One Zero
            ColorMask A

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragA

            ENDCG
        }
    }
    Fallback Off
}