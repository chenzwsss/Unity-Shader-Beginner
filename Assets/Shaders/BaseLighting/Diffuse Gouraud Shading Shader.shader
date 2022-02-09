Shader "Unlit/Diffuse Gouraud Shading Shader"
{
    Properties
    {
        _DiffuseColor ("Diffuse Color", Color) = (1.0, 1.0, 1.0, 1.0)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags { "LightMode"="ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct v2f
            {
                float4 pos : SV_POSITION;
                fixed3 color : COLOR;
            };

            fixed4 _DiffuseColor;
            fixed4 _Specular;
            fixed _Gloss;

            v2f vert (appdata_full v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 worldPos = mul(UNITY_MATRIX_M, v.vertex);
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);

                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));

                fixed3 diffuse = _LightColor0.rgb * _DiffuseColor.rgb * saturate(dot(worldNormal, lightDir));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                // Phong
                // fixed3 reflectDir = normalize(reflect(-lightDir, worldNormal));
                // fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);

                // Blinn-Phong
                fixed3 halfDir = normalize(viewDir + lightDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);

                o.color = ambient + diffuse + specular;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4(i.color, 1.0);
            }
            ENDCG
        }
    }
    Fallback "Specular"
}
