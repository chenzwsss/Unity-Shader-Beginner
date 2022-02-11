Shader "Custom/Chapter7-MaskTexture"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        _MainTex ("Main Tex", 2D) = "white" {}
        _BumpMap ("Bump Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1.0
        // 高光反射遮罩纹理
        _SpecularMask ("Specular Mask", 2D) = "white" {}
        // 控制遮罩影响度的系数
        _SpecularScale ("Specular Scale", Float) = 1.0
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
            // 主纹理 _MainTex、 法线纹理 _BumpMap 和遮罩纹理 _SpecularMask 定义了它们共同使 用 的 纹理属性变量 _MainTex_ST。
            // 这意味着，在材质面板中修改主纹理的平铺系数和偏移系数会 同时影响 3 个纹理的采样。
            // 使用这种方式可以让我们节省需要存储的纹理坐标数目，如果我们为 每一个纹理都使用一个单独的属性变量 TextureName_ST, 那么随着使用的纹理数目的增加，我们 会迅速占满顶点着色器中可以使用的插值寄存器。
            // 而很多时候，我们不需要对纹理进行平铺和位 移操作，或者很多纹理可以使用同一种平铺和位移操作，此时我们就可以对这些纹理使用同一个 变换后 的 纹理坐标进行采样。
            float4 _MainTex_ST;
            sampler2D _BumpMap;
            float _BumpScale;
            sampler2D _SpecularMask;
            float _SpecularScale;
            fixed4 _Specular;
            float _Gloss;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                float3 worldPos = mul(UNITY_MATRIX_M, v.vertex).xyz;
                // 计算世界空间下的法线矢量
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                // 计算世界空间下的顶点切线矢量
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                // 计算世界空间下的副切线矢量
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

                // 把它们 按列 摆放得到 从切线 空间到世界空 间的变换矩阵 。 
                // 我们把该矩阵的每一行x, y, z分别存储 在 TtoW0、 TtoW1 和 TtoW2 中，并把世界空间下的顶点位置的 xyz 分别分别存储在了这些变量的 w 分量中， 以便充分利用插值寄存器的存储空间。
                // 按列摆放
                o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
                o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
                o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // 首先从 TtoW0、 TtoW1 和 TtoW2 的 w 分量中构建世界空间下的坐标
                float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);

                // 通过内置函数UnityWorldSpaceLightDir得到世界空间下的光照方向和视角方向，并normalize
                fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));

                // 对法线纹理进行采样和解码
                fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv));
                // 通过_BumpScale进行缩放来控制凹凸程度
                bump.xy *= _BumpScale;
                // 根据存储的x, y求出z
                bump.z = sqrt(1.0 - saturate(dot(bump.xy, bump.xy)));

                // 使用 TtoW0、TtoW1 和 TtoW2 存储的变换矩阵把法线变换到世界空间下。
                // 这是通过使用 点乘操作来实现矩阵的每一行和法线相 乘来得到的。
                // dot(i.TtoW0.xyz, bump)得出x，dot(i.TtoW1.xyz, bump)得出y，dot(i.TtoW2.xyz, bump)得出z
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(lightDir, bump));

                fixed specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;

                fixed3 halfDir = normalize(viewDir + lightDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, bump)), _Gloss) * specularMask;

                return fixed4(ambient + diffuse + specular, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}