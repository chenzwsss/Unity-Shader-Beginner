Shader "Custom/Chapter7-NormalMapWorldSpace"
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

                // 一个插值寄存器最多只能存储 float4 大小的变量，对于矩阵这样的变量，我们可以把它们按行拆成多个变量再进行存储。
                // TtoW0、 TtoW1 和 TtoW2 就依 次存储了从切线空间到世界空间的变换矩阵的每一行。
                // 实际上，对方向矢量的变换只需要使用 3X3 大小的矩阵，也就是说，每一行只需要使用 float3 类型的变量即可。
                // 但为了充分利用插值寄存器 的存储空间，我们把世界空间下的顶点位置存储在这些变堆的 w 分量中。
                float4 TtoW0 : TEXCOORD1;
                float4 TtoW1 : TEXCOORD2;
                float4 TtoW2 : TEXCOORD3;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                // 分别计算主纹理和法线纹理的uv
                o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                o.uv.zw = v.texcoord.xy * _BumpMap_ST.xy + _BumpMap_ST.zw;

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
                fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));
                // 通过_BumpScale进行缩放来控制凹凸程度
                bump.xy *= _BumpScale;
                // 根据存储的x, y求出z
                bump.z = sqrt(1.0 - saturate(dot(bump.xy, bump.xy)));

                // 使用 TtoW0、TtoW1 和 TtoW2 存储的变换矩阵把法线变换到世界空间下。
                // 这是通过使用 点乘操作来实现矩阵的每一行和法线相 乘来得到的。
                // dot(i.TtoW0.xyz, bump)得出x，dot(i.TtoW1.xyz, bump)得出y，dot(i.TtoW2.xyz, bump)得出z
                bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

                fixed3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Color.rgb;

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 diffuse = _LightColor0.rgb * albedo * saturate(dot(bump, lightDir));

                fixed3 halfDir = normalize(lightDir + viewDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(halfDir, bump)), _Gloss);

                return fixed4(ambient + diffuse + specular, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}