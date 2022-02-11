Shader "Custom/Chapter6-DiffuseFlat"
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
                float3 worldPos : TEXCOORD0;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                // 把顶底坐标转换到世界坐标
                o.worldPos = mul(UNITY_MATRIX_M, v.vertex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                // 在默认的情况下我们在fragment shader使用的法线都是经过三角形三个顶点的法线插值得到的，要达成flat shading的效果我们需要让整个三角形上的fragment的法线相同
                // 要达成flat shading的效果我们需要让整个三角形上的fragment的法线相同。
                // 于是我们可以使用ddx,ddy函数，其作用是求目标参数在屏幕X和Y方向的偏导。根据查到的信息，fragment总是在一个2x2的块中处理，使用ddx,ddy时当前fragment总能获得块中其他三个fragment的信息，因此将目标参数的插值返回即得到X和Y方向的偏导。
                // 对传入的世界坐标求偏导，就可以得到两个平面上的向量，再叉乘就能获得法线
                // 由于三角形的世界坐标是线性变化的，每个像素得到的ddx和ddy都是相同的，于是所有fragment得到的法线都是其所在的三角形上的法线，即可得到flat shading的效果。
                fixed3 worldDdx = ddx(i.worldPos);
                fixed3 worldDdy = ddy(i.worldPos);
                fixed3 flatWorldNormal = normalize(cross(worldDdy, worldDdx));
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(flatWorldNormal, worldLight));



                return fixed4(ambient + diffuse, 1.0);
            }

            ENDCG
        }
    }
    Fallback Off
}