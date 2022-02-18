using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MotionBlurWithDepthTexture : PostEffectsBase
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
    // 定义运动模糊时模糊图像使用的大小
    [Range(0.0f, 1.0f)]
    public float blurSize = 0.5f;
    // 由于本节需要得到摄像机的视角和投影矩阵 ，我们 需要定义一个 Camera 类型 的变量 ，以获取该脚本所在的摄像机组件
    private Camera myCamera;
    public Camera camera
    {
        get{
            if (myCamera == null)
            {
                myCamera = GetComponent<Camera>();
            }
            return myCamera;
        }
    }

    // 我们还需要定义一个变量来保存上一帧摄像机的视角*投影矩阵
    private Matrix4x4 previousViewProjectionMatrix;

    // 由于本例需要获取摄像机的深度纹理 ， 我们在脚本的 OnEnable 函数中设置摄像机的状态
    void OnEnable()
    {
        camera.depthTextureMode |= DepthTextureMode.Depth;
    }

    // 首先需要计算和传递运动模糊使用的各个属性
    // 本例需要使用两个变换矩阵，前一帧的视角*投影矩阵以及当前帧的视角*投影矩阵的逆矩阵
    // 因此我们通过调用 camera.worldToCameraMatrix 和 camera.projectionMatrix 来分别得到当前摄像机的视角矩阵和投影矩阵
    // 对它们相乘后取逆 ， 得到当前帧的视角*投影矩阵 的逆矩阵 ， 并传递给材质
    // 然后 ，我们把取逆前 的结果存储在 previousViewProjectionMatrix 变量中 ，以便在下一帧时传递给材质的 _PreviousViewProjectionMatrix 属性
    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (material != null)
        {
            material.SetFloat("_BlurSize", blurSize);

            material.SetMatrix("_PreviousViewProjectionMatrix", previousViewProjectionMatrix);
            Matrix4x4 currentViewProjectionMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
            Matrix4x4 currentViewProjectionInverseMatrix = currentViewProjectionMatrix.inverse;
            material.SetMatrix("_CurrentViewProjectionInverseMatrix", currentViewProjectionInverseMatrix);
            previousViewProjectionMatrix = currentViewProjectionMatrix;

            Graphics.Blit(src, dest, material);
        }
        else
        {
            Graphics.Blit(src, dest);
        }
    }
}
