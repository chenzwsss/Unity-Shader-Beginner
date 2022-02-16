// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Chapter11-Billboard"
{
    Properties
    {
        // _MainTex是广告牌显示的透明纹理
        _MainTex ("Main Tex", 2D) = "white" {}
        // _Color 用千控制显示整体颜色
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // _VerticalBillboarding 则用于调整是固定法线还是固定指向上的方向，即约束垂直方向的程度
        _VerticalBillboarding ("Vertical Restraints", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "IgnoreProjector"="True" "Queue"="Transparent" }
        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            float _VerticalBillboarding;

            struct a2v
            {
                float4 vertex : POSITION;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            v2f vert(a2v v)
            {
                v2f o;

                // 顶点着色器是我们 的核心，所有的计算都是在模型空间下进行的。

                // 我们首先选择模型空间的原点作为广告牌的锚点 ，并利用内置变量获取模型空间下的视角位置
                float3 center = float3(0.0, 0.0, 0.0);
                float3 viewer = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));

                // 然后 ，我们开始计算 3 个正交矢量

                // 首先，我们根据观察位置和描点计算目标法线方向，并根据 _VerticalBillboarding 属性来控制垂直方向上的约束度
                // 当 _Vertica!Billboarding 为1时 ，意味着法线方向固定为视角方向；当 _VerticalBillboarding 为0时 ，意味着向上方向固定为 (0, 1, 0) 。最后 ， 我们需要对计算得到的法线方向进行归一化操作来得到单位矢量
                float3 normalDir = viewer - center;
                normalDir.y = normalDir.y * _VerticalBillboarding;
                normalDir = normalize(normalDir);

                // 接着 ，我们得到了粗略的向上方向
                // 为了防止法线方向和向上方向平行（如果平行，那么叉积得到的结果将是错误的） ，我们对法线方向的 y 分量进行判断，以得到合适的向上方向
                float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                // 然后，根据法线方 向和粗略 的向 上方向得到向右方向 ，并对结果进行归一化
                float3 rightDir = normalize(cross(upDir, normalDir));
                // 但由于此时向上的方向还是不准确的 ，我们又根据准确的法线方向和向右方向得到最后的向上方向
                upDir = normalize(cross(normalDir, rightDir));
                // 这样 ，我们得到了所需的 3 个正交基矢量。我们根据原始的位置相对于锚点的偏移量以及3个正交基矢量，以计算得到新的顶点位置
                float3 centerOffs = v.vertex.xyz - center;
                float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
                // 最后，把模型空间的顶点位置变换到裁剪空间中
                o.pos = UnityObjectToClipPos(float4(localPos, 1));

                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 c = tex2D(_MainTex, i.uv);
                c.rgb *= _Color.rgb;
                return c;
            }

            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}