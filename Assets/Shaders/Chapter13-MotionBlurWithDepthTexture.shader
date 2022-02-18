Shader "Custom/Chapter13-MotionBlurWithDepthTexture"
{
    Properties
    {
        _MainTex ("Main Tex", 2D) = "white" {}
        _BlurSize ("Blur Size", Float) = 1.0
        // 虽然在脚本里设置了材质的_PreviousViewProjectionMatrix 和 _CurrentViewProjectionlnverseMatrix 属性，但并没有在 Properties 块中声明它们。
        // 这是因为 Unity 没有提供矩阵类型的属性，但我们仍然可以在 CG 代码块中定义这些矩阵，并从脚本中设置它们。
    }
    SubShader
    {
        CGINCLUDE

        #include "UnityCG.cginc"

        sampler2D _MainTex;
        half4 _MainTex_TexelSize;
        // _CameraDepthTexture 是 Unity 传递给我们的深度纹理
        sampler2D _CameraDepthTexture;
        // 而 _CurrentViewProjectioninverseMatrix 和 _PreviousViewProjectionMatrix 是由脚本传递而来的矩阵
        float4x4 _CurrentViewProjectionInverseMatrix;
        float4x4 _PreviousViewProjectionMatrix;
        half _BlurSize;

        struct v2f
        {
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
            half2 uv_depth : TEXCOORD1;
        };

        v2f vert(appdata_img v)
        {
            v2f o;

            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv = v.texcoord;
            o.uv_depth = v.texcoord;

            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
                o.uv_depth.y = 1 - o.uv_depth.y;
            #endif

            return o;
        }

        fixed4 frag(v2f i) : SV_Target
        {
            // 我们首先需要利用深度纹理和当前帧的视角＊投影矩阵的逆矩阵来求得该像素在世界空间下的坐标

            // 过程开始于对深度纹理的采样，我们使用内置的 SAMPLE_DEPTH_TEXTURE 宏和纹理坐标对深度纹理进行采样 ，得到了 深度值 d。由 13.1.2 节可知 ， d 是由 NDC 下的坐标映射而来的
            // 我们想要构建像素的 NDC 坐标 H,就需要把这个深度值重新映射回 NDC 。这个映射很简单 ，只需要使用原映射的反函数即可 ，即 d * 2 - 1
            // 同样 ， NDC 的 xy 分量可以由像素的纹理坐标映射而来( NDC 下的 xyz 分量范 围均为 [-1, 1] )
            // 当得到 NDC 下的坐标 H 后，我们就可以使用当前帧的视角＊投影矩阵的逆矩阵对其进行变换，并把结果值除以它的 w 分量来得到世界空间下的坐标表示 worldPos
            float d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth);
            float4 H = float4(i.uv.x * 2 - 1, i.uv.y * 2 - 1, d * 2 - 1, 1);
            float4 D = mul(_CurrentViewProjectionInverseMatrix, H);
            float4 worldPos = D / D.w;

            // 一旦得到了世界空间下的坐标 ，我们就可以使用前一帧的视角＊投影矩阵对它进行变换 ， 得到前一帧在 NDC 下的坐标 previousPos 
            float4 currentPos = H;
            float4 previousPos = mul(_PreviousViewProjectionMatrix, worldPos);
            previousPos /= previousPos.w;

            // 然后，我们计算前一帧和当前帧在屏幕空间下的位置差 ，得到该像素的速度 velocity 。
            float2 velocity = (currentPos.xy - previousPos.xy) / 2.0f;

            // 当得到该像素的速度后，我们就可以使用该速度值对它的邻域像素进行采样 ，相加后取平均值得到一个模糊的效果。采样时我们还使用了 _BJurSize 来控制采样距离
            float2 uv = i.uv;
            float4 c = tex2D(_MainTex, uv);
            uv += velocity * _BlurSize;
            for (int it = 1; it < 3; ++it, uv += velocity * _BlurSize)
            {
                float4 currentColor = tex2D(_MainTex, uv);
                c += currentColor;
            }
            c /= 3;
            return fixed4(c.rgb, 1.0);
        }

        ENDCG
        Pass
        {
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            ENDCG
        }
    }
    Fallback Off
}