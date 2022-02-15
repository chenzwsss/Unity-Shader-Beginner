Shader "Custom/Chapter10-GlassRefraction"
{
    Properties
    {
        // _MainTex 是该玻璃的材质纹理，默认为白色纹理；
        _MainTex ("Main Tex", 2D) = "white" {}
        // _BumpMap 是玻璃的法线纹理；
        _BumpMap ("Normal Map", 2D) = "bump" {}
        // _Cubemap 是用于模拟反射的环境纹理；
        _Cubemap ("Environment Cubemap", Cube) = "_Skybox" {}
        // _Distortion 则用于控制模拟折射时图像的扭曲程度；
        _Distortion ("Distortion", Range(0, 100)) = 10
        // _ RefractAmount 用于控制折射程度，当_RefractAmount 值为0时，该玻璃只包含反射效果，当_ RefractAmount 值为1时，该玻璃只包括折射效果
        _RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0
    }
    SubShader
    {
        // 我们首先在 SubShader 的标签中将渲染队列设置成 Transparent, 尽管在后面的 RenderType 被设置为了Opaque 。这两者看似矛盾，但实际上服务于不同的需求。
        // 我们在之前说过，把Queue设置成 Transparent 可以确保该物体渲染时，其他所有不透明物体都已经被渲染到屏幕上了，否则就可能无法正确得到“透过玻璃看到的图像”
        // 而设置RenderType 则是为了在使用着色器替换(Shader Replacement) 时，该物体可以在需要时被正确渲染。这通常发生在我们需要得到摄像机的深度和法线纹理时，这将会在第 13 章中学到。
        Tags { "RenderType"="Opaque" "Queue"="Transparent" }

        // 通过关键词 GrabPass 定义了一个抓取屏幕图像的 Pass 。在这个 Pass 中我们定义了 一个字符串，该字符串内部的名称决定了抓取得到的屏幕图像将会被存入哪个纹理中。实际上，我们可以省略声明该字符串，但直接声明纹理名称的方法往往可以得到更高的性能，具体原因可以参见本节最后的部分。
        GrabPass { "_RefractionTex" }

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            samplerCUBE _Cubemap;
            float _Distortion;
            fixed _RefractAmount;
            // 需要注意的是，我们还定义了_RefractionTex 和_RefractionTex_TexelSize 变量，这对应了在使用 GrabPass 时指定的纹理名称。
            // _RefractionTex_TexelSize 可以让我们得到该纹理的纹素大小，例如一个大小为 256X512 的纹理，它的纹素大小为 (1/256, 1/512) 。我们需要在对屏幕图像的采样坐标进行偏移时使用该变量。
            sampler2D _RefractionTex;
            float4 _RefractionTex_TexelSize;

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 scrPos : TEXCOORD0;
                float4 uv : TEXCOORD1;
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4;
                SHADOW_COORDS(5)
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                // 在进行了必要的顶点坐标变换后 ， 我们通过调用内置的 ComputeGrabScreenPos 函数来得到对应被抓取的屏幕图像的采样坐标。
                // 读者可以在 UnityCG.cginc 文件中找到它的声明 ， 它的主要代码和 ComputeScreenPos 基本类似，最大的不同是针对平台差异造成的采样坐标问题（详见 5.6.1 节）进行了处理。
                o.scrPos = ComputeGrabScreenPos(o.pos);

                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);

                float3 worldPos = mul(UNITY_MATRIX_M, v.vertex);
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 我们首先通过 TtoWO 等变量的 w 分量得到世界坐标 ，并用该值得到该片元对应的视角方向。
                float3 worldPos = float3(i.TtoW0.z, i.TtoW1.z, i.TtoW2.z);
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                // 随后，我们对法线纹理进行采样，得到切线空间下的法线方向。
                fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));

                // 我们使用该值和 _Distortion 属性以及 _RefractionTex_TexelSize 来对屏幕图像的采样坐标进行偏移，模拟折射效果。_Distortion 值越大，偏移量越大 ，玻璃背后的物体看起来变形程度越大。
                // 在这里，我们选择使用切线空间下 的法线方向来进行偏移 ，是因为该空间下的法线可以反映顶点局部空间下的法线方向。
                float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                i.scrPos.xy = offset + i.scrPos.xy;
                // 随后 ，我们对 scrPos 透视除法得到真正的屏幕坐标（原理可参见 4.9.3 节），再使用该坐标对抓取的屏幕图像 _RefractionTex 进行采样，得到模拟的折射颜色。
                fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy / i.scrPos.w).rgb;

                // 之后，我们把法线方向从切线空间变换到了世界空间下（使用变换矩阵的每一行，即 TtoWO 、TtoW1 和TtoW2,分别和法线方向点乘，构成新的法线方向），并据此得到视角方向相对于法线方向的反射方向。
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

                // 随后，使用反射方向对 Cubemap 进行采样，并把结果和主纹理颜色相乘后得到反射颜色。
                fixed3 reflDir = reflect(-worldViewDir, bump);
                fixed4 texColor = tex2D(_MainTex, i.uv.xy);
                fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb;

                // 最后 ，我们使用_RefractAmount 属性对反射和折射颜色进行混合，作为最终的输出颜色。
                fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount;

                return fixed4(finalColor, 1.0);
            }

            ENDCG
        }
    }
    Fallback "Specular"
}