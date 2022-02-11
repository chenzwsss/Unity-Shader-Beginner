Shader "Custom/Chapter7-NormalDiffuse"
{
    Properties
    {
        // 为了控制物体的整体色调，我们还声明了 一个_Color属性
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // 声明了 一个名为 _MainTex 的纹理
        _MainTex ("Main Tex", 2D) = "white" {}

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
            sampler2D _BumpMap;
            float _BumpScale;

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

                return fixed4(ambient + diffuse, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}