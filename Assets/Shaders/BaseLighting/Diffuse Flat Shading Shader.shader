Shader "Unlit/Diffuse Shader"
{
    Properties
    {
        _DiffuseColor ("Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct v2f
            {
                float4 vertex : SV_POSITION;
                fixed4 worldPos : TEXCOORD0;
            };

            fixed4 _DiffuseColor;
            fixed4 _Specular;
            fixed _Gloss;

            v2f vert (appdata_full v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed3 worldDx = ddx(i.worldPos);
                fixed3 worldDy = ddy(i.worldPos);
                fixed3 worldNormal = normalize(cross(worldDy, worldDx));

                fixed3 worldPos = normalize(i.worldPos);
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

                // 环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 漫反射
                fixed3 diffuse = _LightColor0.rgb * _DiffuseColor.rgb * saturate(dot(worldNormal, lightDir));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                // Phong
                // fixed3 reflectDir = normalize(reflect(-lightDir, worldNormal));
                // fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);

                // Blinn-Phong
                fixed3 halfDir = normalize(lightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);

                fixed3 color = ambient + diffuse + specular;
                return fixed4(color, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Specular"
}
