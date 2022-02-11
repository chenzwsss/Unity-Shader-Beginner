Shader "Custom/Chapter7-SingleTexture"
{
    Properties
    {
        // 为了控制物体的整体色调，我们还声明了 一个_Color属性
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // 声明了 一个名为 _MainTex 的纹理
        _MainTex ("Main Tex", 2D) = "white" {}
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

            #include "Lighting.cginc"

            fixed4 _Color;

            sampler2D _MainTex;
            // 与其他属性类型不同的是，我们还需要为纹理类型的属性声明一个 float4 类型的变量 _MainTex_ST，其中， _MainTex_ST 的名字不是任意起的
            // 在 Unity 中，我们需要使用 纹理名_ST 的方式来声明某个纹理的属性。其中 ST 是缩放 (scale)和平移 (translation)的缩写。
            // _MainTex_ST 可以让我 们得到该纹理的缩放和平移 (偏移)值 ， _MainTex_ST.xy 存储的是缩放值，而 _MainTex_ST.zw 存储的是偏移值 。
            float4 _MainTex_ST;

            fixed4 _Specular;
            float _Gloss;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);

                o.worldPos = mul(UNITY_MATRIX_M, v.vertex).xyz;

                // 使用纹理的属性值 _MainTex_ST 来对顶点纹理坐标进行变换, 得到最终的纹理坐标
                // 计算过程是，首先使用缩放属性 _MainTex_ST.xy 对顶点纹理坐标进行缩放，然后 再使用偏移属性 _MainTex_ST.zw 对结果进行偏移。
                // o.uv = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;

                // Unity 提供了一个内置宏 TRANSFORM_TEX 来帮我们计算上述过程。 TRANSFORM_TEX 是在 UnityCG.cginc 中 定义 的
                // 它接受两个参数，第一个参数是顶点纹理坐标，第 二个参数是纹理名，在它的实现中，将利 用 纹理名_ST 的方式来计算变换后的纹理坐标。
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 首先计算了世界空间下的法线方向和光照方向
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));

                // 使用 CG 的 tex2D 函数对 纹理进行采样。它的第一个参数是需要被采样的纹理，第二个参数是一个 float2类型的纹理坐标， 它将返回计算得到的纹素值。
                // 我们使用采样结果和颜色属性 _Color 的乘积来作为材质的反射率 albedo
                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(worldLight, worldNormal));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + worldLight);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, worldNormal)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}