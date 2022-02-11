Shader "Custom/Chapter6-DiffusePixelLevel"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader
    {
        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            fixed4 _Diffuse;

            #include "Lighting.cginc"

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD0;
                float4 worldPos : TEXCOORD1;
            };

            v2f vert (a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                // 法线变换到世界坐标
                // 因为是Phong Shading，所以再传给片元着色器
                o.normal = UnityObjectToWorldNormal(v.normal);

                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 worldNormal = normalize(i.normal);
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));
                // 在片元着色器中计算漫反射
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));

                return fixed4(ambient + diffuse, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}