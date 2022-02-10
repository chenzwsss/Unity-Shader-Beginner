Shader "Custom/Chapter 5/Simple Shader"
{
    Properties
    {
        // 声明一个Color类型的属性
        _Color ("Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader
    {
        Pass
        {
            CGPROGRAM

            // 告诉 Unity, 哪个函数包含了顶点着色器的代码，哪个函数包含了片元着色器的代码。更通用的编译指令表示如下:
            // #pragma vertex name
            // #pragma vertex name
            // 其中 name 就是我们指定的函数名
            #pragma vertex vert
            #pragma fragment frag

            // 在CG代码中， 我们需要定义一个与属性名称和类型都匹配的变量
            fixed4 _Color;

            // 使用一个结构体来定义顶点着色器的输入
            struct a2v {
                // POSITION语义告诉Unity, 用模型空间的顶点坐标填充vertex变量
                float4 vertex : POSITION;
                // NORMAL语义告诉Unity, 用模型空间的法线方向填充normal变量
                float3 normal : NORMAL;
                // TEXCOORDO语义告诉Unity, 用模型的第一套纹理坐标填充texcoord变量
                float4 texcoord : TEXCOORD0;
            };

            // 使用一个结构体来定义顶点着色器的输出
            struct v2f {
                // SV_POSITION语义告诉Unity, pos里包含了顶点在裁剪空间中的位置信息
                float4 pos : SV_POSITION;
                // COLOR0语义可以用于存储颜色信息
                fixed3 color : COLOR0;
            };

            // 顶点着色器代码，它是逐顶点执行的。vert 函数的输入 v 包含了这个顶点 的位置，这是通过 POSITION 语义指定的。
            // 它的返回值是一个 float4 类型的变量，它是该顶点在 裁剪空间中的位置， POSITION 和 SV_POSITION 都是 CG/HLSL 中的语义 (semantics), 它们是 不可省略的，这些语义将告诉系统用户需要哪些输入值，以及用户的输出是什么。
            // 如这里，POSITION将告诉 Unity, 把模型的顶点坐标填充到输入参数 v 中，
            // SV_POSITION将告诉 Unity, 顶点着色器的输出是裁剪空间中的顶点坐标。
            v2f vert(a2v v)
            {
                // 声明输出结构
                v2f o;

                // 把顶点坐标从模型空间转换到裁剪空间中
                o.pos = UnityObjectToClipPos(v.vertex);

                // v.normal包含了顶点的法线方向 ， 其分量范围在[-1.0, 1.0]
                // 下面的代码把分量范围映射到了[0.0, 1.0]
                // 存储到a.color中传递给片元着色器
                o.color = v.normal * 0.5 + fixed3(0.5, 0.5, 0.5);

                return o;
            }

            // SV_Target也是 HLSL 中的一个系统语义，它等同于告诉渲染器，把用户的输出颜 色存储到 一个渲染目标 (rendertarget) 中，这里将输出到默认的帧缓存中
            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 c = i.color;
                c *= _Color.rgb;
                // 将插值后的i.color显示到屏幕上
                return fixed4(c, 1.0);
            }
            ENDCG
        }
    }
}