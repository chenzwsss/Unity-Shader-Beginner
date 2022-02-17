Shader "Custom/Chapter12-BrightnessSaturationAndContrast"
{
    Properties
    {
        // 我们提到 Graphics.Blit(src, dest, material)将把第一个参数传递给 Shader 中名为_MainTex 的属性。因此，我们必须声明 一个名为_MainTex 的纹理属性
        _MainTex ("Main Tex", 2D) = "white" {}
        // 除此之外，我们还声明了用于调整亮度 、饱和度和对比度的属性。这些值将会由脚本传递而得
        // 事实上，我们可以省略 Properties 中的属性声明，Properties 中声明的属性仅仅是为了显示在材质面板中，但对于屏幕特效来说，它们使用的材质都是临时创建的，我们也不需要在材质面板上调整参数，而是直接从脚本传递给 Unity Shader
        _Brightness ("Brightness", Float) = 1.0
        _Saturation ("Saturation", Float) = 1.0
        _Contrast ("Contrast", Float) = 1.0
    }
    SubShader
    {
        Pass
        {
            // 屏幕后处理实际上是在场景中绘制了 一个与屏幕同宽同高的四边形面片，为了防止它对其他物体产生影响，我们需要设置相关的渲染状态
            // 在这里，我们关闭了深度写入，是为了防止它“挡住”在其后面被渲染的物体
            // 例如，如果当前的 OnRenderImage 函数在所有不透明的 Pass 执行完毕后立即被调用，不关闭深度写入就会影响后面透明的 Pass 的渲染。这些状态设置可以认为是用于屏幕后处理的 Shader 的“标配”。
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            sampler2D _MainTex;
            half _Brightness;
            half _Saturation;
            half _Contrast;

            #include "UnityCG.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
            };

            // 在下面的顶点着色器中，我们使用了 Unity 内置的 appdata_img 结构体作为顶点着色器的输入，读者可以在 UnityCG.cginc 中找到该结构体的声明，它只包含了图像处理时必需的顶点坐标和纹理坐标等变量
            v2f vert(appdata_img v)
            {
                v2f o;

                // 定义顶点着色器。屏幕特效使用的顶点着色器代码通常都比较简单 ，我们只需要进行必需的顶点变换，更重要的是，我们需要把正确的纹理坐标传递给片元着色器，以便对屏幕图像进行正确的采样
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 首先，我们得到对原屏幕图像（存储在 _MainTex 中）的采样结果renderTex
                fixed4 renderTex = tex2D(_MainTex, i.uv);
                // 然后，利用 _Brightness 属性来调整亮度。亮度的调整非常简单，我们只需要把原颜色乘以亮度系数 _Brightness 即可
                fixed3 finalColor = renderTex.rgb * _Brightness;
                // 然后，我们计算该像素对应的亮度值(Luminance),这是通过对每个颜色分盘乘以一个特定的系数再相加得到的
                fixed luminance = 0.2125 * renderTex.r + 0.7154 * renderTex.g + 0.0721 * renderTex.b;
                // 我们使用该亮度值创建了一个饱和度为0 的颜色值，并使用_Saturation属性在其和上一步得到的颜色之间进行插值，从而得到希望的饱和度颜色
                fixed3 luminanceColor = fixed3(luminance, luminance, luminance);
                finalColor = lerp(luminanceColor, finalColor, _Saturation);
                // 比度的处理类似，我们首先创建一个对比度为 0 的颜色值 （各分量均为 0.5), 再使用_Contrast 属性在其和上一步得到的颜色之间进行插值，从而得到最终的处理结果
                fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
                finalColor = lerp(avgColor, finalColor, _Contrast);

                return fixed4(finalColor, renderTex.a);
            }

            ENDCG
        }
    }
    Fallback Off
}