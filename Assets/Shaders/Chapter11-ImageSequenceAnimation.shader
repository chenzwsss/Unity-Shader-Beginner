Shader "Custom/Chapter11-ImageSequenceAnimation"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // _MainTex 就是包含了所有关键帧图像的纹理
        _MainTex ("Image Sequence", 2D) = "white" {}
        // _HorizontalAmount 和 _VerticalAmount 分别代表了该图像在水平方向和竖直方向包含的关键帧图像的个数
        _HorizontalAmount ("Horizontal Amount", Float) = 4.0
        _VerticalAmount ("Vertical Amount", Float) = 4.0
        // 而 _Speed 属性用于控制序列帧动画的播放速度。
        _Speed ("Speec", Range(1, 100)) = 30
    }
    SubShader
    {
        // 由于序列帧图像通常是透明纹理，我们需要设置 Pass 的相关状态，以渲染透明效果
        // 由于序列帧图像通常包含了透明通道， 因此可以被当成是一个半透明对象。 在这里我们使用半透明的“标配”来设置它的SubShader标签，
        // 即把Queue和RenderType设置成 Transparent, 把IgnoreProjector设翌为 True。 在 Pass中，我们使用 Blend命令来开启并设置混合模式，同时关闭了深度写入。
        Tags { "RenderType"="Transparent" "IngoreProjector"="True" "Queue"="Transparent" }
        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed _HorizontalAmount;
            fixed _VerticalAmount;
            fixed _Speed;

            struct a2v
            {
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {

                // 要播放帧动画，从本质来说， 我们需要计算出每个时刻需要播放的关键帧在纹理中的位置 。而由于序列帧纹理都是按行按列排列的，因此这个位置可以认为是该关键帧所在的行列索引数 。
                // 因此，在上面的代码的前3行中我们计算了行列数， 其中使用了Unity的内置时间变操_Time。 由11.1节可以知道， _Time.y 就是自该场景加载后所经过的时间。 我们首先把_Time.y 和速度属性_Speed相乘来得到模拟的时间，并使用CG的floor函数对结果值取整来得到整数时间 time。 
                // 然后，我们使用 time 除以_HorizontalAmount 的结果值的商来作为当前对应的行索引， 除法结果的余数则是列索引 。
                // 接下来，我们需要使用行列索引值来构建真正的采样坐标。
                // 由于序列帧图像包含了许多关键帧图像， 这意味着采样坐标需要映射到每个关键帧图像的坐标范围内。 我们可以首先把原纹理坐标 i.uv按行数和列数进行等分， 得到每个子图像的纹理坐标范围 。
                // 然后，我们需要使用当前的行列数对上面的结果进行 偏移，得到当前子图像的纹理坐标。

                // 需要注意的是， 对 竖直方向的坐标偏移需要使用减法， 这是因为在Unity中纹理坐标竖直方向的顺序（从下到上逐渐增大）和序列帧纹理中的顺序（播放顺序是从上到下）是相反的 。
                // 这对应了下面代码中注释掉的代码部分。 我们可以把上述过程中的除法整合到一起，就得到了注释下方的代码 。 这样，我们就得到了真正的纹理采样坐标。
                float time = floor(_Time.y * _Speed);
                float row = floor(time / _HorizontalAmount);
                float colum = time - row * _HorizontalAmount;

                // half2 uv = float2(i.uv.x / _HorizontalAmount, i.uv.y / _VerticalAmount);
                // uv.x += colum / _HorizontalAmount;
                // uv.y -= row / _VerticalAmount;

                half2 uv = i.uv + half2(colum, -row);
                uv.x /= _HorizontalAmount;
                uv.y /= _VerticalAmount;

                fixed4 c = tex2D(_MainTex, uv);
                c.rgb *= _Color;

                // 保存后返回场景，我们将 Assets/Textures/Chapter11/Boom.png (注意，由于是透明纹理，因此盆要勾选该纹理的Alpha Is Transparency属性）赋给ImageSequenceAnimationMat 中的ImageSequence属性，
                // 并将Horizontal Amount和Vertical Amount设置为8 ( 因为Boom.png包含了8行8 列的关键帧图像），完成后单击播放 ，并调整 Speed 属性，就可以得到一段连续的爆炸动画。
                return c;
            }

            ENDCG
        }
    }
    Fallback Off
}