using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GaussianBlur : PostEffectsBase
{
    public Shader gaussianBlurShader;
    private Material gaussianBlurMaterial = null;
    public Material material
    {
        get
        {
            gaussianBlurMaterial = CheckShaderAndCreateMaterial(gaussianBlurShader, gaussianBlurMaterial);
            return gaussianBlurMaterial;
        }
    }

    // 高斯模糊迭代次数
    [Range(0, 4)]
    public int iterations = 3;
    // 模糊范围
    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;
    // 缩放系数
    [Range(1, 8)]
    public int downSample = 2;

    // blurSpread 和 downSample 都是出于性能的考虑。在高斯核维数不变的情况下 ，_BlurSize 越大，模糊程度越高 ， 但采样数却不会受到影响。但过大的_BlurSize 值会造成虚影 ， 这可能并不是我们希望的。而 downSample 越大 ，
    // 需要处理的像素数越少，同时也能进一步提高模糊程度 ，但过大的 downSample 可能会使图像像素化。

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {

            // 利用 RenderTexture.GetTemporary 函数分配了一块与屏幕图像大小相同的缓冲区。这是因为 ，高斯模糊需要调用两个 Pass,我们需要使用一块中间缓存来存储第一个Pass 执行完毕后得到的模糊结果。

            // 声明缓冲区的大小时 ， 使用了小于原屏幕分辨率的尺寸，并将该临时渲染纹理的滤波模式设置为双线性。
            // 这样，在调用第一个 Pass 时，我们 需要处理的像素个数就是原来的几分之一。对图像进行降采样不仅可以减少需要处理的像素个数，提高性能，而且适当的降采样往往还可以得到更好的模糊效果。
            // 尽管 downSample 值越大，性能越好，但过大的 downSample 可能会造成图像像素化。
            int rtW = src.width/downSample;
            int rtH = src.height/downSample;

            // 在迭代开始前，我们首先定义了第一个缓存 buffer0, 并把 src 中的图像缩放后存储到 buffer0 中。
            RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer0.filterMode = FilterMode.Bilinear;
            Graphics.Blit(src, buffer0);

            // 在迭代过程中，我们又定义了第二个缓存 buffer1 。在执行第一个 Pass 时，输入是 buffer0, 输出是 buffer1,完毕后首先把 buffer0 释放，再把结果值 buffer1 存储到 buffer0 中，重新分配 buffer1, 
            // 然后再调用第二个Pass, 重复上述过程。迭代完成后 ，buffer0 将存储最终的图像，我们再利用 Graphics.Blit(bufferO ,dest)把结果显示到屏幕上，并释放缓存。
            for (int i = 0; i < iterations; ++i)
            {
                material.SetFloat("_BlurSize", 1.0f + i * blurSpread);

                RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                Graphics.Blit(buffer0, buffer1, material, 0);

                RenderTexture.ReleaseTemporary(buffer0);

                buffer0 = buffer1;

                buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                Graphics.Blit(buffer0, buffer1, material, 1);

                RenderTexture.ReleaseTemporary(buffer0);

                buffer0 = buffer1;
            }

            Graphics.Blit(buffer0, dest, material);

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
