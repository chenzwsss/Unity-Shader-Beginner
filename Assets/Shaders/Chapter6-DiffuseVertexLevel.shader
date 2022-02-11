Shader "Custom/Chapter6-DiffuseVertexLevel"
{
    Properties
    {
        // 漫反射颜色
        _Diffuse ("Diffuse", Color) = (1.0, 1.0, 1.0, 1.0)
    }

    SubShader
    {
        Pass
        {
            // LightMode 标签是 Pass 标签中的 一 种，它用于定义该 Pass 在 Unity 的光照流水线中的角色，
            // 只有定义了正确的 LightMode, 我们才能得到一些 Unity 的内置光照变量，例如下面要讲到的_LightColorO。
            Tags { "LightMode" = "ForwardBase" }

            // CGPROGRAM和 ENDCG 来包围 CG 代码片
            CGPROGRAM

            // 使用#pragma指令来告诉 Unity, 我们定义的顶点着色器和片元着色器叫什么名字 
            #pragma vertex vert
            #pragma fragment frag

            // 为了使用 Unity 内置的 一 些变量，如后面要讲到的 _LightColorO, 还需要包含进 Unity 的 内置文件 Lighting.cginc
            #include "Lighting.cginc"

            fixed4 _Diffuse;

            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                fixed3 color : COLOR;
            };

            v2f vert(a2v v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                // 环境光
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                // 法线转换到世界坐标系，并normalize
                fixed3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
                // 世界坐标系中的光源方向
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(mul(UNITY_MATRIX_M, v.vertex)));

                // 计算漫反射
                // saturate 函数是 CG 提供的 一种函数，它的作用是可以把参数截取到 [O, 1]的范围内 。
                // 最后 ，再与光源的颜色和强度以 及材质的漫反射颜色相乘即可得到最终的漫反射光照部分 。
                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldLight, worldNormal));
                // 最后，我们对环境光和漫反射光部分相加，得到最终的光照结果。
                o.color = ambient + diffuse;

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