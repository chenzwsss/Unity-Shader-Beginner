Shader "Custom/Chapter18-CustomPBR"
{
    Properties
    {
        _Color ("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex ("Albedo", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0.0, 1.0)) = 0.5
        _SpecularColor ("Specular", Color) = (0.2, 0.2, 0.2)
        _SpecularGlossMap ("Specular (RGB) Smoothness (A)", 2D) = "white" {}
        _BumpScale ("Bump Scale", Float) = 1.0
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _EmissionColor ("Color", Color) = (0.0, 0.0, 0.0)
        _EmissionMap ("Emission", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 300

        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma target 3.0

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Glossiness;
            fixed3 _SpecularColor;
            sampler2D _SpecularGlossMap;
            // float4 _SpecularGlossMap_ST;
            float _BumpScale;
            sampler2D _BumpMap;
            // float4 _BumpMap_ST;
            fixed3 _EmissionColor;
            sampler2D _EmissionMap;
            // float4 _EmissionMap_ST;

            struct a2v
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
                SHADOW_COORDS(4)
                UNITY_FOG_COORDS(5)
            };

            v2f vert(a2v v)
            {
                v2f o;

                UNITY_INITIALIZE_OUTPUT(v2f, o);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                float3 worldPos = mul(UNITY_MATRIX_M, v.vertex).xyz;
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                TRANSFER_SHADOW(o);

                UNITY_TRANSFER_FOG(o, o.pos);

                return o;
            }

            inline half3 CustomDisneyDiffuseTerm(half NdotV, half NdotL, half LdotH, half roughness, half3 baseColor)
            {
                half fd90 = 0.5 + 2 * LdotH * LdotH * roughness;

                half lightScatter = (1 + (fd90 - 1) * pow(1 - NdotL, 5));
                half viewScatter = (1 + (fd90 - 1) * pow(1 - NdotV, 5));

                return baseColor * UNITY_INV_PI * lightScatter * viewScatter;
            }

            inline half CustomSmithJointGGXVisibilityTerm(half NdotL, half NdotV, half roughness)
            {
                // Original formulation:
                // lambda_v = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5f;
                // lambda_l = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5f;
                // G = 1 / (1 + lambda_v + lambda_l);

                // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
                half a2 = roughness * roughness;
                half lambdaV = NdotL * (NdotV * (1 - a2) + a2);
                half lambdaL = NdotV * (NdotL * (1 - a2) + a2);

                return 0.5f / (lambdaV + lambdaL + 1e-5f);
            }

            inline half CustomGGXTerm(half NdotH, half roughness)
            {
                half a2 = roughness * roughness;
                half d = (NdotH * a2 - NdotH) * NdotH + 1.0f;
                return UNITY_INV_PI * a2 / (d * d + 1e-7f);
            }

            inline half3 CustomFresnelTerm(half3 c, half cosA)
            {
                half t = pow(1 - cosA, 5);
                return c + (1 - c) * t;
            }

            inline half3 CustomFresnelLerp(half3 c0, half3 c1, half cosA)
            {
                half t = pow(1 - cosA, 5);
                return lerp(c0, c1, t);
            }

            half4 frag(v2f i) : SV_Target
            {
                half4 specGloss = tex2D(_SpecularGlossMap, i.uv);
                specGloss.a *= _Glossiness;
                half3 specColor = specGloss.rgb * _SpecularColor.rgb;
                half roughness = 1 - specGloss.a;

                half oneMinusReflectivity = 1 - max(max(specColor.r, specColor.g), specColor.b);

                half3 diffColor = _Color.rgb * tex2D(_MainTex, i.uv).rgb * oneMinusReflectivity;

                half3 normalTangent = UnpackNormal(tex2D(_BumpMap, i.uv));
                normalTangent.xy *= _BumpScale;
                normalTangent.z = sqrt(1.0 - saturate(dot(normalTangent.xy, normalTangent.xy)));

                half3 normalWorld = normalize(half3(dot(i.TtoW0.xyz, normalTangent), dot(i.TtoW1.xyz, normalTangent), dot(i.TtoW2.xyz, normalTangent)));

                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
                half3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                half3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                half3 reflDir = reflect(-viewDir, normalWorld);

                UNITY_LIGHT_ATTENUATION(atten, i, worldPos);

                half3 halfDir = normalize(lightDir + viewDir);
                half nv = saturate(dot(normalWorld, viewDir));
                half nl = saturate(dot(normalWorld, lightDir));
                half nh = saturate(dot(normalWorld, halfDir));
                half lv = saturate(dot(lightDir, viewDir));
                half lh = saturate(dot(lightDir, halfDir));

                half3 diffuseTerm = CustomDisneyDiffuseTerm(nv, nl, lh, roughness, diffColor);

                half V = CustomSmithJointGGXVisibilityTerm(nl, nv, roughness);
                half D = CustomGGXTerm(nh, roughness * roughness);
                half3 F = CustomFresnelTerm(specColor, lh);
                half3 specularTerm = F * V * D;

                half3 emisstionTerm = tex2D(_EmissionMap, i.uv).rgb * _EmissionColor.rgb;

                half perceptualRoughness = roughness * (1.7 - 0.7 * roughness);
                half mip = perceptualRoughness * 6;
                half4 envMap = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, mip);
                half grazingTerm = saturate(1 - roughness) + (1 - oneMinusReflectivity);
                half surfaceReduction = 1.0 / (roughness * roughness + 1.0);
                half3 indirectSpecular = surfaceReduction * envMap.rgb * CustomFresnelLerp(specColor, grazingTerm, nv);

                half3 col = emisstionTerm + UNITY_PI * (diffuseTerm + specularTerm) * _LightColor0.rgb * nl * atten + indirectSpecular;

                UNITY_APPLY_FOG(i.fogCoord, c.rgb);

                return half4(col, 1.0);
            }
            ENDCG
        }
    }
    Fallback Off
}