using UnityEngine;
using System.Collections;

// 首先 ， 所有屏幕后 处理效果都需要绑定在某个摄像机上 ， 并且我们希望在编辑器状态下也可以执行该脚本来查看效果
[ExecuteInEditMode]
[RequireComponent (typeof(Camera))]
public class PostEffectsBase : MonoBehaviour {

    // Called when start
    protected void CheckResources() {
        bool isSupported = CheckSupport();
        
        if (isSupported == false) {
            NotSupported();
        }
    }

    // Called in CheckResources to check support on this platform
    protected bool CheckSupport() {
        if (SystemInfo.supportsImageEffects == false || SystemInfo.supportsRenderTextures == false) {
            Debug.LogWarning("This platform does not support image effects or render textures.");
            return false;
        }
        
        return true;
    }

    // Called when the platform doesn't support this effect
    protected void NotSupported() {
        enabled = false;
    }
    
    protected void Start() {
        CheckResources();
    }

    // Called when need to create the material used by this effect
    // CheckSbaderAndCreateMateriaJ 函数接受两个参数 ，第一个参数指定了该特效需要使用的Shader, 第二个参数则是用千后期处理的材质。该函数首先检查 Shader 的可用性，检查通过后就返回一个使用了该 Shader 的材质，否则返回 null 。
    protected Material CheckShaderAndCreateMaterial(Shader shader, Material material) {
        if (shader == null) {
            return null;
        }
        
        if (shader.isSupported && material && material.shader == shader)
            return material;
        
        if (!shader.isSupported) {
            return null;
        }
        else {
            material = new Material(shader);
            material.hideFlags = HideFlags.DontSave;
            if (material)
                return material;
            else 
                return null;
        }
    }
}
