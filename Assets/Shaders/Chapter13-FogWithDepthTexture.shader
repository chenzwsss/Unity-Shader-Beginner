Shader "Custom/Chapter13-FogWithDepthTexture"
{
    Properties
    {
        _MainTex ("Main Tex(RGB)", 2D) = "white" {}
        _FogDensity ("Fog Density", Float) = 1.0
        _FogColor ("Fog Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _FogStart ("Fog Start", Float) = 0.0
        _FogEnd ("Fog End", Float) = 1.0
    }
    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"

        // _FrustumCornersRay 虽 然没有在 Properties 中声明 ，但仍可由脚本传递给Shader 
        float4x4 _FrustumCornersRay;

        sampler2D _MainTex;
        half4 _MainTex_TexelSize;
        // 我们还声明了深度纹理 _CameraDepthTexture, Unity 会在背后把得到的深度纹理传递给该值
        sampler2D _CameraDepthTexture;
        half _FogDensity;
        fixed4 _FogColor;
        float _FogStart;
        float _FogEnd;

        // 在 v2f 结构体中，我们除了定义顶点位置、屏幕图像和深度纹理的纹理坐标外，还定义了 interpolatedRay 变量存储插值后的像素向量
        struct v2f
        {
            float4 pos : SV_POSITION;
            half2 uv : TEXCOORD0;
            half2 uv_depth : TEXCOORD1;
            float4 interpolatedRay : TEXCOORD2;
        };

        v2f vert(appdata_img v)
        {
            v2f o;

            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv = v.texcoord;

            o.uv_depth = v.texcoord;

            // 在顶点着色器中，我们对深度纹理的采样坐标进行了平台差异化处理
            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
                o.uv_depth.y = 1.0 - o.uv_depth.y;
            #endif

            // 更重要的是，我们要决定该点对应了 4 个角中的哪个角。我们采用的方法是判断它的纹理坐标
            // 我们知道，在 Unity 中，纹理坐标的 (0, 0)点对应了左下角，而(1, 1)点对应了右上角。我们据此来判断该顶点对应的索引，这个对应关系和我们在脚本中对 _FrustumCornersRay 的赋值顺序是一致的
            // 实际上，不同平台的纹理坐标不一定是满足上面的条件的，例如 DirectX 和 Metal 这样的平台，左上角对应了 (0, 0)点，但大多数情况下 Unity 会把这些平台下的屏幕图像进行翻转，因此我们仍然可以利用这个条件
            // 但如果在类似 DirectX 的平台上开启了抗锯齿，Unity就不会进行这个翻转。为了此时仍然可以得到相应顶点位置的索引值，我们对索引值也进行了平台差异化处理（详见 5.6.1 节），以便在必要时也对索引值进行翻转
            int index = 0;
            if (v.texcoord.x < 0.5 && v.texcoord.y < 0.5)
            {
                index = 0;
            }
            else if (v.texcoord.x > 0.5 && v.texcoord.y < 0.5)
            {
                index = 1;
            }
            else if (v.texcoord.x > 0.5 && v.texcoord.y > 0.5)
            {
                index = 2;
            }
            else
            {
                index = 3;
            }

            #if UNITY_UV_STARTS_AT_TOP
            if (_MainTex_TexelSize.y < 0)
                index = 3 - index;
            #endif

            // 最后，我们使用索引值来获取 _FrustumCornersRay 中对应的行作为该顶点的 interpolatedRay 值
            o.interpolatedRay = _FrustumCornersRay[index];

            // 尽管我们这里使用了很多判断语句，但由于屏幕后处理所用的模型是一个四边形网格，只包含 4 个顶点，因此这些操作不会对性能造成很大影响

            return o;
        }

        fixed4 frag(v2f i) : SV_Target
        {
            // 首先，我们需要重建该像素在世界空间中的位置
            // 为此，我们首先使用 SAMPLE_DEPTH_TEXTURE 对深度纹理进行采样，再使用 LinearEyeDepth 得到视角空间下的线性深度值
            // 之后，与 interpolatedRay 相乘后再和世界空间下的摄像机位置相加，即可得到世界空间下的位置
            // 得到世界坐标后，模拟雾效就变得非常容易。在本例中，我们选择实现基于高度的雾效模拟，计算公式可参见 13.3.2 节。我们根据材质属性 _FogEnd 和 _FogStart 计算当前的像素高度 worldPos.y对应的雾效系数 fogDensity,
            // 再和参数 _FogDensity 相乘后，利用 saturate 函数截取到 [O, 1]范围内，作为最后的雾效系数。然后，我们使用该系数将雾的颜色和原始颜色进行混合后返回。读者也可以使用不同的公式来实现其他种类的雾效。
            float linearDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv_depth));
            float3 worldPos = _WorldSpaceCameraPos + linearDepth * i.interpolatedRay.xyz;

            float fogDensity = (_FogEnd - worldPos.y) / (_FogEnd - _FogStart);
            fogDensity = saturate(fogDensity * _FogDensity);

            fixed4 finalColor = tex2D(_MainTex, i.uv);
            finalColor.rgb = lerp(finalColor.rgb, _FogColor.rgb, fogDensity);
            return finalColor;
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