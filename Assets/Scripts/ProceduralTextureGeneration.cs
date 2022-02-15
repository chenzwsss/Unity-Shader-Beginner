using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class ProceduralTextureGeneration : MonoBehaviour
{
    public Material material = null;

    // #region 和 #endregion 仅仅是为了组织代码，并没有其他作用。
    #region Material properties

    // 注意到，对于每个属性我们使用了 get/set 的方法，为了在面板上修改属性时仍可以执行 set 函数，
    // 我们使用了一个开源插件 SetProperty(https://github.com/LMNRY/SetProperty/blob/master/Scripts/SetPropertyExample.cs) 。这使得当我们修改了材质属性时，可以执行 _UpdateMaterial 函数来使用新的属性重新生成程序纹理。

    // 纹理的大小，数值通常是 2 的整数幕；
    [SerializeField, SetProperty("textureWidth")]
    private int m_textureWidth = 512;
    public int textureWidth
    {
        get
        {
            return m_textureWidth;
        }
        set
        {
            m_textureWidth = value;
            _UpdateMaterial();
        }
    }
    // 纹理的背景颜色
    [SerializeField, SetProperty("backgroundColor")]
    private Color m_backgroundColor = Color.white;
    public Color backgroundColor
    {
        get
        {
            return m_backgroundColor;
        }
        set
        {
            m_backgroundColor = value;
            _UpdateMaterial();
        }
    }
    // 圆点的颜色
    [SerializeField, SetProperty("circleColor")]
    private Color m_circleColor = Color.yellow;
    public Color circleColor
    {
        get
        {
            return m_circleColor;
        }
        set
        {
            m_circleColor = value;
            _UpdateMaterial();
        }
    }
    // 模糊因子，这个参数是用来模糊圆形边界的
    [SerializeField, SetProperty("blurFactor")]
    private float m_blurFactor = 2.0f;
    private float blurFactor
    {
        get
        {
            return m_blurFactor;
        }
        set
        {
            m_blurFactor = value;
            _UpdateMaterial();
        }
    }
    #endregion

    // 为了保存生成的程序纹理，我们声明一个 Texture2D 类型的纹理变量
    private Texture2D m_generatedTexture = null;

    // Start is called before the first frame update
    void Start()
    {
        if (material == null)
        {
            Renderer renderer = gameObject.GetComponent<Renderer>();
            if (renderer == null)
            {
                Debug.LogWarning("Cannot find a renderer.");
                return;
            }
            material = renderer.sharedMaterial;
        }
        _UpdateMaterial();
    }

    private void _UpdateMaterial()
    {
        if (material != null)
        {
            m_generatedTexture = _GenerateProceduralTexture();
            material.SetTexture("_MainTex", m_generatedTexture);
        }
    }
    
    private Color _MixColor(Color color0, Color color1, float mixFactor) {
        Color mixColor = Color.white;
        mixColor.r = Mathf.Lerp(color0.r, color1.r, mixFactor);
        mixColor.g = Mathf.Lerp(color0.g, color1.g, mixFactor);
        mixColor.b = Mathf.Lerp(color0.b, color1.b, mixFactor);
        mixColor.a = Mathf.Lerp(color0.a, color1.a, mixFactor);
        return mixColor;
    }

    private Texture2D _GenerateProceduralTexture()
    {
        Texture2D proceduralTexture = new Texture2D(textureWidth, textureWidth);

        float circleInterval = textureWidth / 4.0f;
        float radius = textureWidth / 10.0f;
        float edgeBlur = 1.0f / blurFactor;

        for (int w = 0; w < textureWidth; ++w)
        {
            for (int h = 0; h < textureWidth; ++h)
            {
                Color pixel = backgroundColor;

                for (int i = 0; i < 3; ++i)
                {
                    for (int j = 0; j < 3; ++j)
                    {
                        Vector2 circleCenter = new Vector2(circleInterval * (i + 1), circleInterval * (j + 1));
                        float dist = Vector2.Distance(new Vector2(w, h), circleCenter) - radius;

                        Color color = _MixColor(circleColor, new Color(pixel.r, pixel.g, pixel.b, 0.0f), Mathf.SmoothStep(0f, 1.0f, dist * edgeBlur));

                        pixel = _MixColor(pixel, color, color.a);
                    }
                }
                proceduralTexture.SetPixel(w, h, pixel);
            }
        }
        proceduralTexture.Apply();
        return proceduralTexture;
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
