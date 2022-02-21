Shader "Custom/Chapter17-NormalExtrusion"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex ("Main Tex(RGB)", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _Amount ("Extrusion Amount", Range(-0.5, 0.5)) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 300

        CGPROGRAM

        // surf - which surface function.
        // CustomLambert - which lighting model to use.
        // vertex:myvert - use custom vertex modification function.
        // finalcolor:mycolor - use custom final color modification function.
        // addshadow - generate a shadow caster pass. Because we modify the vertex position, the shder needs special shadows handling.
        // exclude_path:deferred/exclude_path:prepas - do not generate passes for deferred/legacy deferred rendering path.
        // nometa - do not generate a “meta” pass (that’s used by lightmapping & dynamic global illumination to extract surface information).
        #pragma surface surf CustomLambert vertex:myvert finalcolor:mycolor addshadow exclude_path:deferred exclude_path:prepass nometa
        #pragma target 3.0

        fixed4 _Color;
        sampler2D _MainTex;
        sampler2D _BumpMap;
        half _Amount;

        struct Input
        {
            float2 uv_MainTex;
            float2 uv_BumpMap;
        };

        void myvert(inout appdata_full v)
        {
            v.vertex.xyz += v.normal * _Amount;
        }

        void surf (Input IN, inout SurfaceOutput o)
        {
            fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);
            o.Albedo = tex.rgb * _Color.rgb;
            o.Alpha = tex.a * _Color.a;
            o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
        }

        half4 LightingCustomLambert(SurfaceOutput s, half3 lightDir, half atten)
        {
            half NdotL = dot(s.Normal, lightDir);
            half4 c;
            c.rgb = s.Albedo * _LightColor0.rgb * (NdotL * atten);
            c.a = s.Alpha;
            return c;
        }

        void mycolor(Input IN, SurfaceOutput o, inout fixed4 color)
        {
            color *= _Color;
        }

        ENDCG
    }
    Fallback "Legacy Shaders/Diffuse"
}