Shader "Custom/Chapter11-Water"
{
    Properties
    {
        // _MainTex 是河流纹理
        _MainTex ("Main Tex", 2D) = "white" {}
        // _Color 用于控制整体颜色
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        // _Magnitude 用于控制水流波动的幅度
        _Magnitude ("Distortion Magnitude", Float) = 1.0
        // _Frequency 用于控制波动频率
        _Frequency ("Distortion Frequency", Float) = 1.0
        // _InvWaveLength 用于控制波长的倒数 (_InvWaveLength 越大，波长越小）
        _InvWaveLength ("Distortion Inverse Wave Length", Float) =  10.0
        // _Speed 用于控制河流纹理的移动速度
        _Speed ("Speed", Float) = 0.5
    }
    SubShader
    {
        // 为透明效果设置 Queue 、IgnoreProjector 和 RenderType
        // DisableBatching：一些 SubShader 在使用 Unity 的批处理功能时会出现问题，这时可以通过该标签来直接指明是否对该 SubShader 使用批处理。
        // 而这些需要特殊处理的 Shader 通常就是指包含了模型空间的顶点动画的 Shader。这是因为，批处理会合并所有相关的模型，而这些模型各自的模型空间就会丢失。
        // 而在本例中，我们需要在物体的模型空间下对顶点位置进行偏移。因此，在这里需要取消对该 Shader 的批处理操作。
        Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True" }
        Pass
        {
            Tags { "LightMode"="ForwardBase" }

            // 关闭了深度写入，开启并设置了混合模式，并关闭了剔除功能。这是为了让水流的每个面都能显示。
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
            float _Magnitude;
            float _Frequency;
            float _InvWaveLength;
            float _Speed;

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

                // 首先计算顶点位移量
                // 我们只希望对顶点的 x 方向进行位移，因此 yzw 的位移猛被设置为0
                // 然后 ，我们利用 _Frequency 属性和内置的 _Time.y 变墓来控制正弦函数的频率
                // 为了让不同位置具有不同的位移，我们对上述结果加上了模型空间下的位置分量，并乘以 _InvWaveLength 来控制波长
                // 最后，我们对结果值乘以 _Magnitude 属性来控制波动幅度，得到最终的位移
                // 剩下的工作，我们只需要把位移量添加到顶点位置上 ，再进行正常的顶点变换即可。
                float4 offset;
                offset.yzw = float3(0.0, 0.0, 0.0);
                offset.x = sin(_Frequency * _Time.y + v.vertex.x * _InvWaveLength + v.vertex.y * _InvWaveLength + v.vertex.z * _InvWaveLength) * _Magnitude;

                o.pos = UnityObjectToClipPos(v.vertex + offset);

                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

                // 我们还进行了纹理动画，即使用 _Time.y 和 _Speed 来控制在水平方向上的纹理动画。
                o.uv += float2(0.0, _Time.y * _Speed);

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