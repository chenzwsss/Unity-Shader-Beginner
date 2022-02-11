// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Chapter7-NormalMapTangentSpace"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex ("Main Tex", 2D) = "white" {}
        _Specular ("Specular", Color) = (1.0, 1.0, 1.0, 1.0)
        _Gloss ("Gloss", Range(8.0, 256)) = 20

        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1.0
    }
    SubShader
    {
        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Specular;
            float _Gloss;

            sampler2D _BumpMap;
            float4 _BumpMap_ST;
            float _BumpScale;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                // 我们使用 TANGENT 语义来描述float4类型的 tangent变量，以告诉Unity把顶点的切线方向填 充到 tangent 变量中
                // 需要注意的是，和法线方向 normal 不同， tangent 的类型是 float4, 而非 float3,
                // 这是因为我们需要使用 tangent.w 分量来决定切线空间中的第三个坐标轴，副切线的方向性。
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                // 由于我们使用了两张纹理，因此需要存储两个纹理坐标。为此，我们把 v2f中的 UV 变量的类型定义为float4类型，
                // 其中xy分量存储了_MainTex的纹理坐标， 而zw分量存储了_BumpMap的 纹理坐标(实际上 ， _MainTex 和_BumpMap 通 常会使用同一组纹理坐标 ，出 千 减少插 值寄存 器的 使用数目的目 的， 我们往往只计算和存储一 个 纹理坐标即可))
                float4 uv : TEXCOORD0;
                float3 lightDir : TEXCOORD1;
                float3 viewDir : TEXCOORD2;
            };

            // Unity doesn't support the 'inverse' function in native shader
            // so we write one by our own
            // Note: this function is just a demonstration, not too confident on the math or the speed
            // Reference: http://answers.unity3d.com/questions/218333/shader-inversefloat4x4-function.html
            float4x4 inverse(float4x4 input) {
                #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))

                float4x4 cofactors = float4x4(
                     minor(_22_23_24, _32_33_34, _42_43_44), 
                    -minor(_21_23_24, _31_33_34, _41_43_44),
                     minor(_21_22_24, _31_32_34, _41_42_44),
                    -minor(_21_22_23, _31_32_33, _41_42_43),
                    
                    -minor(_12_13_14, _32_33_34, _42_43_44),
                     minor(_11_13_14, _31_33_34, _41_43_44),
                    -minor(_11_12_14, _31_32_34, _41_42_44),
                     minor(_11_12_13, _31_32_33, _41_42_43),
                    
                     minor(_12_13_14, _22_23_24, _42_43_44),
                    -minor(_11_13_14, _21_23_24, _41_43_44),
                     minor(_11_12_14, _21_22_24, _41_42_44),
                    -minor(_11_12_13, _21_22_23, _41_42_43),
                    
                    -minor(_12_13_14, _22_23_24, _32_33_34),
                     minor(_11_13_14, _21_23_24, _31_33_34),
                    -minor(_11_12_14, _21_22_24, _31_32_34),
                     minor(_11_12_13, _21_22_23, _31_32_33)
                );
                #undef minor
                return transpose(cofactors) / determinant(input);
            }

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                
                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

                ///
                /// Note that the code below can handle both uniform and non-uniform scales
                ///

                // Construct a matrix that transforms a point/vector from tangent space to world space
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 

                float4x4 tangentToWorld = float4x4(worldTangent.x, worldBinormal.x, worldNormal.x, 0.0,
                                                   worldTangent.y, worldBinormal.y, worldNormal.y, 0.0,
                                                   worldTangent.z, worldBinormal.z, worldNormal.z, 0.0,
                                                   0.0, 0.0, 0.0, 1.0);
                // The matrix that transforms from world space to tangent space is inverse of tangentToWorld
                float3x3 worldToTangent = inverse(tangentToWorld);
                
                //wToT = the inverse of tToW = the transpose of tToW as long as tToW is an orthogonal matrix.
                // float3x3 worldToTangent = float3x3(worldTangent, worldBinormal, worldNormal);

                // Transform the light and view dir from world space to tangent space
                o.lightDir = mul(worldToTangent, WorldSpaceLightDir(v.vertex));
                o.viewDir = mul(worldToTangent, WorldSpaceViewDir(v.vertex));

                ///
                /// Note that the code below can only handle uniform scales, not including non-uniform scales
                /// 

                // Compute the binormal
//                float3 binormal = cross( normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w;
//                // Construct a matrix which transform vectors from object space to tangent space
//                float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
                // Or just use the built-in macro
//                TANGENT_SPACE_ROTATION;
//                
//                // Transform the light direction from object space to tangent space
//                o.lightDir = mul(rotation, normalize(ObjSpaceLightDir(v.vertex))).xyz;
//                // Transform the view direction from object space to tangent space
//                o.viewDir = mul(rotation, normalize(ObjSpaceViewDir(v.vertex))).xyz;
                
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 tangentLightDir = normalize(i.lightDir);
                fixed3 tangentViewDir = normalize(i.viewDir);

                // 首先利用 tex2D对法线纹理_BumpMap进行采样
                fixed4 packedNormal = tex2D(_BumpMap, i.uv.zw);
                fixed3 tangentNormal;

                // 法线纹理中存储的是把法线经过映射后得到 的像素值 ， 因此我们需要把它们反映射回来
                // 如果我们没有在Unity里把该法线纹理的类型设置成 Normal map， 就需要在代码 中手动进行这个过程。
                // 我们首先把 packedNormal 的 xy 分量按之前提到的公式映射回法线方向
                // tangentNormal.xy = (packedNormal.xy * 2 - 1) * _BumpScale;

                // or mark the texture as "Normal map", and use the built-in function
                tangentNormal = UnpackNormal(packedNormal);

                // 然后乘以 _BumpScale (控制凹凸程度)来得到 tangentNormal 的 xy 分量
                tangentNormal *= _BumpScale;

                // 由于法线都是单位矢量 ， 因此 tangentNormal.z分量可以由 tangentNonnal.xy计算而得
                // 由于我们使用的是切线空间下的法 线纹理 ， 因此可以保证法线方向的 z分量为正。

                // 因为法线都是单位矢量，所以法线的长度是1，通过在三维坐标系中分解一个向量可以知道这个向量的长度等于x^2+y^2+z^2
                // 点乘dot(tangentNormal.xy, tangentNormal.xy)可以得到x*x+y*y=x^2+y^2
                // 所以这里可以求出z
                tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

                fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(tangentNormal, tangentLightDir));

                fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, tangentNormal)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}