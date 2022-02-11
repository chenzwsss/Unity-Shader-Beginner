Shader "Custom/Chapter6-SpecularVertexLevel"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1.0, 1.0, 1.0, 1.0)
        _Specular ("Specular", Color) = (1.0, 1.0, 1.0, 1.0)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
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
            fixed4 _Specular;
            float _Gloss;

            #include "Lighting.cginc"

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                fixed3 color : COLOR0;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                // 法线变换到世界坐标
                fixed3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
                // 顶点左边变换到世界坐标
                fixed3 worldPos = mul(UNITY_MATRIX_M, v.vertex);

                // 世界坐标下的光源方向
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(worldPos));

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));

                // 相机坐标和顶点位置坐标求出视线坐标
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
                // 反射方向
                // 由于 CG 的 reflect 函数的入射方向要求是由光源 指向交点处的，因此我们需要对 worldLight 取反后再传给 reflect 函数

                // // Phong
                // fixed3 reflectDir = normalize(reflect(-worldLight, worldNormal));
                // // 根据反射方向和视线坐标算高光
                // fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(viewDir, reflectDir)), _Gloss);

                // Blinn-Phong

                // Phong光照模型和Blinn-Phong光照模型的区别：
                // Phong是算反射光线和视线的夹角
                // Blinn-Phong是算半程向量和法线的夹角，简化了计算
                fixed3 halfDir = normalize(worldLight + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);

                o.color = ambient + diffuse + specular;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return fixed4(i.color, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}