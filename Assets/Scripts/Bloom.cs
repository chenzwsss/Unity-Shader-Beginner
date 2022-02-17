using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Bloom : PostEffectsBase
{
    public Shader bloomShader;
    private Material bloomMaterial = null;
    public Material material
    {
        get
        {
            bloomMaterial = CheckShaderAndCreateMaterial(bloomShader, bloomMaterial);
            return bloomMaterial;
        }
    }

    // 由于 Bloom 效果是建立在高斯模糊的基础上的 ， 因此脚本中提供的参数和 12.4节中 的几 乎完全一样 ，
    // 我们 只增加了一个新的参数 luminanceThreshold 来控制提取较亮区域时使用的阙值 大小 :
    [Range(0, 4)]
    public int iterations = 3;

    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;

    [Range(1, 8)]
    public int downSample = 2;

    // 尽管在绝大多数情况下，图像的亮度值不会超过 1。但如果我们开启了 HDR, 硬件会允许我 们把颜色值存储在一个更高精度范围的缓冲中，此时像素的亮度值可能会超过 1。
    // 因此，在这里 我们把 luminanceThreshold 的值规定在[O,4]范围内。更多关于 HDR的内容， 可以参见 18.4.3节。
    [Range(0.0f, 4.0f)]
    public float luminanceThreshold = 0.6f;

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            material.SetFloat("_LuminanceThreshold", luminanceThreshold);

            int rtW = src.width / downSample;
            int rtH = src.height / downSample;

            // Bloom效果需要3个步骤:
            // 首先，提取图像中较亮的区域，因此我们没有像12.4节那样直 接对 src进行降采样，而是通过调用 Graphics.Blit(src, buffer0, material, 0)来使用 Shader 中的第一 个 Pass提取图像中的较亮区域，提取得到的较亮区域将存储在 buffer0 中。
            RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer0.filterMode = FilterMode.Bilinear;

            Graphics.Blit(src, buffer0, material, 0);

            // 然后，我们进行和 12.4 节中完全一样的高斯模糊迭代处理，这些 Pass 对应了 Shader 的第二个和第三个 Pass。
            for (int i = 0; i < iterations; ++i)
            {
                material.SetFloat("_BlurSize", 1.0f + i * blurSpread);

                RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                Graphics.Blit(buffer0, buffer1, material, 1);

                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
                buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                Graphics.Blit(buffer0, buffer1, material, 2);

                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            }
            // 模糊后的 较亮区域将会存储在 buffer0 中，此时，我们再把 buffer0 传递给材质中的_Bloom 纹理属性，并调 用 Graphics.Blit(src, dest, material, 3)使用 Shader 中的第四个 Pass 来进行最后的混合，将结果存储 在目标渲染纹理 dest 中。最后，释放临时缓存。
            material.SetTexture("_Bloom", buffer0);
            Graphics.Blit(src, dest, material, 3);

            RenderTexture.ReleaseTemporary(buffer0);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
    // // Start is called before the first frame update
    // void Start()
    // {
        
    // }

    // // Update is called once per frame
    // void Update()
    // {
        
    // }
}
