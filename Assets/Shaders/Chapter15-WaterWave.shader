Shader "Custom/Chapter15-WaterWave"
{
    Properties
    {
        // _Color 用于控制水面颜色
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // _MainTex 是水面波纹材质纹理， 默认为白色纹理 
        _MainTex ("Main Tex (RGB)", 2D) = "white" {}
        // _WaveMap 是一个由噪声纹理生成的法线纹理
        _WaveMap ("Wave Map", 2D) = "bump" {}
        // _Cubemap 是用于模拟反射的立方体纹理
        _CubeMap ("Environment Cubemap", Cube) = "_Skybox" {}
        // _WaveXSpeed 和 _WaveYSpeed 分别用 于控制法线 纹理在 X 和 Y 方向上的平移速度
        _WaveXSpeed ("Wave Horizontal Speed", Range(-0.1, 0.1)) = 0.01
        _WaveYSpeed ("Wave Vertical Speed", Range(-0.1, 0.1)) = 0.01
        // _Distortion 则用 于控制模拟折 射时图像的扭曲程度
        _Distortion ("Distortion", Range(0, 100)) = 10
    }
    SubShader
    {
        // Queue 设置成 Transparent 可以确保该物体渲染时，其他所有不透明 物体都已经被 渲染到屏幕上了 ， 否 则 就可能无法正确得到“透过水面看到的图像”
        // 设置 RenderType 成 Opaque 则是为 了在使用着色器替换 (Shader Replacement) 时，该物体可以在需要时被正确渲染
        Tags { "RenderType"="Opaque" "Queue"="Transparent" }

        // 通过 关键词 GrabPass 定义了一个抓取屏幕图像的 Pass，在这个 Pass 中我们定义了一个字符串，该字符串内部的名称决 定了抓取得到的屏幕图像将会被存入哪个纹理中
        GrabPass { "_RefractionTex"}

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _WaveMap;
            float4 _WaveMap_ST;
            samplerCUBE _CubeMap;
            fixed _WaveXSpeed;
            fixed _WaveYSpeed;
            float _Distortion;

            // _RefractionTex 对应了在使 用 GrabPass 时，指 定的纹理名称。
            sampler2D _RefractionTex;
            // _RefractionTex_TexelSize 可以让我们得到该纹理的纹素大小 ， 例如一个大小为 256X512 的纹理，它的纹素大小为(1/256, 1/512)
            // 我们需要在对屏幕图像的采样坐标进行偏移时使用 _RefractionTex_TexelSize
            float4 _RefractionTex_TexelSize;

            struct a2v
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float4 tangent : TANGENT;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 scrPos : TEXCOORD0;
                float4 uv : TEXCOORD1;
                float4 TtoW0 : TEXCOORD2;
                float4 TtoW1 : TEXCOORD3;
                float4 TtoW2 : TEXCOORD4;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);
                // 通过调用 ComputeGrabScreenPos 来得到对应被抓取屏 幕图像的采样坐标
                // 读者可以在 UnityCG.cginc 文件 中找到它的声明 ， 它的主要代码和 ComputeScreenPos 基本类似 ， 最大的不同是针对平台差异造成的采样坐标问题(见 5.6.1 节)进 行了处理。
                o.scrPos = ComputeGrabScreenPos(o.pos);
                // 接着，我们计算了 _MainTex 和 _BumpMap 的采样坐标，并把它们分别存储在一个 float4 类型变量的 xy 和 zw 分量中
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord, _WaveMap);

                // 由于我们需要在片元着色器中把法线方向从切线空间(由法线纹理 采样得到)变换到世界空间下，以便对 Cubemap 进行采样，
                // 因此，我们需要在这里计算该顶点对 应的从切线空间到世界空间的变换矩阵 ，并把该矩阵的每一 行分别 存储在 TtoW0，TtoW1 和 TtoW2 的 xyz 分量中
                
                // 这里面使用 的数学方法就是，得到切线空间下的 3 个坐标轴 (x、 y、 z 轴分别对 应 了切线、副切线和法线的方向)在世界空间下的表示，再把它们依次按列组成一个变换矩阵即可 
                float3 worldPos = mul(UNITY_MATRIX_M, v.vertex).xyz;
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

                // TtoW0，TtoW1，TtoW2 变量的 w 分量同样被利用起来， 用于存储世界空间 下的顶点坐标

                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 首先通过 TtoW0，TtoW1，TtoW2 变量的 w 分量得到世界坐标，并用该值得到该片元对应的视角方向
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                // 我们还使用内野的 _Time.y 变量和 _WaveXSpeed，_WaveYSpeed 属性计算了法线纹理 的当前偏移量，
                // 并利用该值对法线纹理进行两次采样(这是为了模拟两层交叉的水面波动的效果)，对两次结果相加并归一化后得到切线空间下的法线方向
                float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);
                fixed3 bump1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + speed)).rgb;
                fixed3 bump2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - speed)).rgb;
                fixed3 bump = normalize(bump1 + bump2);

                // 使用该值和 _Distortion 属性以及 _RefractionTex_TexelSize 来对屏幕图像的采样坐标进行偏移，模拟折射效果
                // _Distortion 值越大，偏移量越大，水面背后的物体看起来变形程度越大
                // 在这里 ， 我们选择使用切线空间下的法线方向来进行偏移，是因为该空间下的法线可以反映顶点局部空间 下的法线方向
                // 需要注意的是，在计算偏移后的屏幕坐标时 ，我们把偏移量和屏幕坐标的 z 分量相乘，这是为了模拟深度越大、折射程度越大的效果
                // 如果读者不希望产生这样的效果 ， 可以直 接把偏移值叠加到屏幕坐标上
                float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                // i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy;
                i.scrPos.xy = i.scrPos.xy + offset;
                // 随后，我们对 scrPos 进行了透视除法，再使用该坐标对抓取的屏 幕图像 _RefractionTex 进行采样，得到模拟的折射颜色
                fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy/i.scrPos.w).rgb;

                // 之后，我们把法线方向从切线空间变换到了世界空间下(使用变换矩阵的每一行，即 TtoW0、 TtoW1 和 TtoW2, 分别和法线方向点乘，构成新的法线方向) 
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

                // 我们也对主纹理进行了纹理动画 ，以模拟水波的效果
                fixed4 texColor = tex2D(_MainTex, i.uv.xy + speed);
                // 并据此得到视角方向相对于法线 方向的反射方向
                fixed3 reflDir = reflect(-viewDir, bump);
                // 使用反射方向对 _CubeMap 进行采样，并把结果和主纹理颜色相乘后得到 反射颜色
                fixed3 reflCol = texCUBE(_CubeMap, reflDir).rgb * texColor.rgb * _Color.rgb;

                // 为了混合折射和反射颜色，我们随后计算了菲涅耳系数。我们使用之前的公式来计算菲涅耳 系数，并据此来混合折射和反射颜色，作为最终的输出颜色。
                fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 4);
                fixed3 finalColor = reflCol * fresnel + refrCol * (1 - fresnel);

                return fixed4(finalColor, 1.0);
            }
            ENDCG
        }
    }
    Fallback Off
}