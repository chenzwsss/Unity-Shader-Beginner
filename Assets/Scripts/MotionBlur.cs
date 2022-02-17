using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MotionBlur : PostEffectsBase
{
    public Shader motionBlurShader;
    private Material motionBlurMaterial = null;

    public Material material
    {
        get
        {
            motionBlurMaterial = CheckShaderAndCreateMaterial(motionBlurShader, motionBlurMaterial);
            return motionBlurMaterial;
        }
    }
    // 定 义运动模糊在混合图像时使用的模糊参数, blurAmount 的值越大，运动拖尾的效果就越明显，为了防止拖尾效果完全替代当前帧的渲染 结果， 我们把它的值截取在0.0-0.9范围内。
    [Range(0.0f, 0.9f)]
    public float blurAmount = 0.5f;

    private RenderTexture accumulationTexture;

    // 我们 在该脚本不运行时 ， 即调用 OnDisable 函数时，立即销毁 accumulationTexture。 这是因为，我们希望在下一次开始应用运动模糊时重新叠加图像。
    void OnDisable()
    {
        DestroyImmediate(accumulationTexture);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            // 在确认材质可用后 ， 我们首先判断用于混合图像的 accumulationTexture 是否满足条件。我们 不仅判断它是否为空 ， 还判断它是否与当前的屏幕分辨率相等，如果不满足 ， 就说明我们需要重 新创建一个适合于当前分辨率的 accumulationTexture变量
            if (accumulationTexture == null || accumulationTexture.width != src.width || accumulationTexture.height != src.height)
            {
                DestroyImmediate(accumulationTexture);

                accumulationTexture = new RenderTexture(src.width, src.height, 0);
                // 创建完毕后， 由于我们会自己控制该 变量的销毁， 因此可以把它的 hideFlags 设置为 HideFlags.HideAndDontSave, 这意味着这个变量 不会显示在 Hierarchy 中 ， 也不会保存到场景中。
                accumulationTexture.hideFlags = HideFlags.HideAndDontSave;
                // 然后 ， 我们使用当前的帧图像初始化 accumulationTexture (使用 Graphics.Blit(src, accumulationTexture)代码)
                Graphics.Blit(src, accumulationTexture);
            }

            // 当得到了有效的 accumulationTexture 变量后 ， 我们调用了 accumulationTexture.MarkRestoreExpected 函数来表明我们需要进行一个渲染纹理的恢复操作。
            // 恢复操作 (restore operation) 发生在渲染到纹理而该纹理又没有被提前清空或销毁的情况下
            // 在本例中 ， 我们每次调用 OnRenderImage 时都需要把当前的帧图像和 accumulationTexture 中的图像混合， accumulationTexture 纹理不需要提前清空 ， 因为它保存了我们之前的混合结果。
            accumulationTexture.MarkRestoreExpected();

            material.SetFloat("_BlurAmount", 1.0f - blurAmount);

            // 然后 ， 我们将参数传递给材质，并调 用 Graphics.Blit(src, accumulationTexture, material)把当前的屏幕图像 src叠加到 accumulationTexture中 
            Graphics.Blit(src, accumulationTexture, material);
            // 最后使用 Graphics.Blit(accumulationTexture, dest)把结果显示到屏幕上
            Graphics.Blit(accumulationTexture, dest);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
