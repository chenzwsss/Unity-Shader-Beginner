// Compiled shader for custom platforms

//////////////////////////////////////////////////////////////////////////
// 
// NOTE: This is *not* a valid shader file, the contents are provided just
// for information and for debugging purposes only.
// 
//////////////////////////////////////////////////////////////////////////
// Skipping shader variants that would not be included into build of current scene.

Shader "Unlit/SingleTextureShader" {
Properties {
 _Specular ("Specular Color", Color) = (1.000000,1.000000,1.000000,1.000000)
 _Gloss ("Gloss", Range(8.000000,256.000000)) = 20.000000
 _MainTex ("Main Tex", 2D) = "white" { }
 _Color ("Color Tint", Color) = (1.000000,1.000000,1.000000,1.000000)
 _BumpMap ("Normal Map", 2D) = "white" { }
 _BumpScale ("Bump Scale", Float) = 1.000000
}
SubShader { 
 LOD 100
 Tags { "RenderType"="Opaque" }
 Pass {
  Tags { "LIGHTMODE"="FORWARDBASE" "RenderType"="Opaque" }
  //////////////////////////////////
  //                              //
  //      Compiled programs       //
  //                              //
  //////////////////////////////////
//////////////////////////////////////////////////////
Keywords: <none>
-- Hardware tier variant: Tier 1
-- Vertex shader for "metal":
Uses vertex data channel "Vertex"
Uses vertex data channel "Normal"
Uses vertex data channel "Tangent"
Uses vertex data channel "TexCoord0"

Constant Buffer "VGlobals" (256 bytes) on slot 0 {
  Matrix4x4 unity_ObjectToWorld at 32
  Matrix4x4 unity_WorldToObject at 96
  Matrix4x4 unity_MatrixVP at 160
  Vector3 _WorldSpaceCameraPos at 0
  Vector4 _WorldSpaceLightPos0 at 16
  Vector4 _MainTex_ST at 224
  Vector4 _BumpMap_ST at 240
}

Shader Disassembly:
#include <metal_stdlib>
#include <metal_texture>
using namespace metal;
struct VGlobals_Type
{
    float3 _WorldSpaceCameraPos;
    float4 _WorldSpaceLightPos0;
    float4 hlslcc_mtx4x4unity_ObjectToWorld[4];
    float4 hlslcc_mtx4x4unity_WorldToObject[4];
    float4 hlslcc_mtx4x4unity_MatrixVP[4];
    float4 _MainTex_ST;
    float4 _BumpMap_ST;
};

struct Mtl_VertexIn
{
    float4 POSITION0 [[ attribute(0) ]] ;
    float3 NORMAL0 [[ attribute(1) ]] ;
    float4 TANGENT0 [[ attribute(2) ]] ;
    float4 TEXCOORD0 [[ attribute(3) ]] ;
};

struct Mtl_VertexOut
{
    float4 mtl_Position [[ position ]];
    float4 TEXCOORD0 [[ user(TEXCOORD0) ]];
    float3 TEXCOORD1 [[ user(TEXCOORD1) ]];
    float3 TEXCOORD2 [[ user(TEXCOORD2) ]];
};

vertex Mtl_VertexOut xlatMtlMain(
    constant VGlobals_Type& VGlobals [[ buffer(0) ]],
    Mtl_VertexIn input [[ stage_in ]])
{
    Mtl_VertexOut output;
    float4 u_xlat0;
    float4 u_xlat1;
    float3 u_xlat2;
    float u_xlat9;
    u_xlat0 = input.POSITION0.yyyy * VGlobals.hlslcc_mtx4x4unity_ObjectToWorld[1];
    u_xlat0 = fma(VGlobals.hlslcc_mtx4x4unity_ObjectToWorld[0], input.POSITION0.xxxx, u_xlat0);
    u_xlat0 = fma(VGlobals.hlslcc_mtx4x4unity_ObjectToWorld[2], input.POSITION0.zzzz, u_xlat0);
    u_xlat0 = u_xlat0 + VGlobals.hlslcc_mtx4x4unity_ObjectToWorld[3];
    u_xlat1 = u_xlat0.yyyy * VGlobals.hlslcc_mtx4x4unity_MatrixVP[1];
    u_xlat1 = fma(VGlobals.hlslcc_mtx4x4unity_MatrixVP[0], u_xlat0.xxxx, u_xlat1);
    u_xlat1 = fma(VGlobals.hlslcc_mtx4x4unity_MatrixVP[2], u_xlat0.zzzz, u_xlat1);
    output.mtl_Position = fma(VGlobals.hlslcc_mtx4x4unity_MatrixVP[3], u_xlat0.wwww, u_xlat1);
    output.TEXCOORD0.xy = fma(input.TEXCOORD0.xy, VGlobals._MainTex_ST.xy, VGlobals._MainTex_ST.zw);
    output.TEXCOORD0.zw = fma(input.TEXCOORD0.xy, VGlobals._BumpMap_ST.xy, VGlobals._BumpMap_ST.zw);
    u_xlat0.x = dot(input.NORMAL0.xyz, input.NORMAL0.xyz);
    u_xlat0.x = rsqrt(u_xlat0.x);
    u_xlat0.xyz = u_xlat0.xxx * input.NORMAL0.zxy;
    u_xlat9 = dot(input.TANGENT0.xyz, input.TANGENT0.xyz);
    u_xlat9 = rsqrt(u_xlat9);
    u_xlat1.xyz = float3(u_xlat9) * input.TANGENT0.yzx;
    u_xlat2.xyz = u_xlat0.xyz * u_xlat1.xyz;
    u_xlat0.xyz = fma(u_xlat0.zxy, u_xlat1.yzx, (-u_xlat2.xyz));
    u_xlat0.xyz = u_xlat0.xyz * input.TANGENT0.www;
    u_xlat1.xyz = VGlobals._WorldSpaceLightPos0.yyy * VGlobals.hlslcc_mtx4x4unity_WorldToObject[1].xyz;
    u_xlat1.xyz = fma(VGlobals.hlslcc_mtx4x4unity_WorldToObject[0].xyz, VGlobals._WorldSpaceLightPos0.xxx, u_xlat1.xyz);
    u_xlat1.xyz = fma(VGlobals.hlslcc_mtx4x4unity_WorldToObject[2].xyz, VGlobals._WorldSpaceLightPos0.zzz, u_xlat1.xyz);
    u_xlat1.xyz = fma(VGlobals.hlslcc_mtx4x4unity_WorldToObject[3].xyz, VGlobals._WorldSpaceLightPos0.www, u_xlat1.xyz);
    u_xlat1.xyz = fma((-input.POSITION0.xyz), VGlobals._WorldSpaceLightPos0.www, u_xlat1.xyz);
    output.TEXCOORD1.y = dot(u_xlat0.xyz, u_xlat1.xyz);
    output.TEXCOORD1.x = dot(input.TANGENT0.xyz, u_xlat1.xyz);
    output.TEXCOORD1.z = dot(input.NORMAL0.xyz, u_xlat1.xyz);
    u_xlat1.xyz = VGlobals._WorldSpaceCameraPos.xyzx.yyy * VGlobals.hlslcc_mtx4x4unity_WorldToObject[1].xyz;
    u_xlat1.xyz = fma(VGlobals.hlslcc_mtx4x4unity_WorldToObject[0].xyz, VGlobals._WorldSpaceCameraPos.xyzx.xxx, u_xlat1.xyz);
    u_xlat1.xyz = fma(VGlobals.hlslcc_mtx4x4unity_WorldToObject[2].xyz, VGlobals._WorldSpaceCameraPos.xyzx.zzz, u_xlat1.xyz);
    u_xlat1.xyz = u_xlat1.xyz + VGlobals.hlslcc_mtx4x4unity_WorldToObject[3].xyz;
    u_xlat1.xyz = u_xlat1.xyz + (-input.POSITION0.xyz);
    output.TEXCOORD2.y = dot(u_xlat0.xyz, u_xlat1.xyz);
    output.TEXCOORD2.x = dot(input.TANGENT0.xyz, u_xlat1.xyz);
    output.TEXCOORD2.z = dot(input.NORMAL0.xyz, u_xlat1.xyz);
    return output;
}


-- Hardware tier variant: Tier 1
-- Fragment shader for "metal":
Set 2D Texture "_BumpMap" to slot 0 sampler slot 1
Set 2D Texture "_MainTex" to slot 1 sampler slot 0

Constant Buffer "FGlobals" (84 bytes) on slot 0 {
  Vector4 glstate_lightmodel_ambient at 0
  Vector4 _LightColor0 at 16
  Vector4 _Specular at 32
  Float _Gloss at 48
  Vector4 _Color at 64
  Float _BumpScale at 80
}

Shader Disassembly:
#include <metal_stdlib>
#include <metal_texture>
using namespace metal;
#ifndef XLT_REMAP_O
	#define XLT_REMAP_O {0, 1, 2, 3, 4, 5, 6, 7}
#endif
constexpr constant uint xlt_remap_o[] = XLT_REMAP_O;
struct FGlobals_Type
{
    float4 glstate_lightmodel_ambient;
    float4 _LightColor0;
    float4 _Specular;
    float _Gloss;
    float4 _Color;
    float _BumpScale;
};

struct Mtl_FragmentIn
{
    float4 TEXCOORD0 [[ user(TEXCOORD0) ]] ;
    float3 TEXCOORD1 [[ user(TEXCOORD1) ]] ;
    float3 TEXCOORD2 [[ user(TEXCOORD2) ]] ;
};

struct Mtl_FragmentOut
{
    float4 SV_Target0 [[ color(xlt_remap_o[0]) ]];
};

fragment Mtl_FragmentOut xlatMtlMain(
    constant FGlobals_Type& FGlobals [[ buffer(0) ]],
    sampler sampler_MainTex [[ sampler (0) ]],
    sampler sampler_BumpMap [[ sampler (1) ]],
    texture2d<float, access::sample > _BumpMap [[ texture(0) ]] ,
    texture2d<float, access::sample > _MainTex [[ texture(1) ]] ,
    Mtl_FragmentIn input [[ stage_in ]])
{
    Mtl_FragmentOut output;
    float2 u_xlat0;
    float3 u_xlat1;
    float3 u_xlat2;
    float3 u_xlat3;
    u_xlat0.x = dot(input.TEXCOORD2.xyz, input.TEXCOORD2.xyz);
    u_xlat0.x = rsqrt(u_xlat0.x);
    u_xlat3.x = dot(input.TEXCOORD1.xyz, input.TEXCOORD1.xyz);
    u_xlat3.x = rsqrt(u_xlat3.x);
    u_xlat3.xyz = u_xlat3.xxx * input.TEXCOORD1.xyz;
    u_xlat1.xyz = fma(input.TEXCOORD2.xyz, u_xlat0.xxx, u_xlat3.xyz);
    u_xlat0.x = dot(u_xlat1.xyz, u_xlat1.xyz);
    u_xlat0.x = rsqrt(u_xlat0.x);
    u_xlat1.xyz = u_xlat0.xxx * u_xlat1.xyz;
    u_xlat2.xyz = _BumpMap.sample(sampler_BumpMap, input.TEXCOORD0.zw).xyw;
    u_xlat2.x = u_xlat2.z * u_xlat2.x;
    u_xlat2.xy = fma(u_xlat2.xy, float2(2.0, 2.0), float2(-1.0, -1.0));
    u_xlat2.xy = u_xlat2.xy * float2(FGlobals._BumpScale);
    u_xlat0.x = dot(u_xlat2.xy, u_xlat2.xy);
    u_xlat0.x = min(u_xlat0.x, 1.0);
    u_xlat0.x = (-u_xlat0.x) + 1.0;
    u_xlat2.z = sqrt(u_xlat0.x);
    u_xlat0.x = dot(u_xlat2.xyz, u_xlat1.xyz);
    u_xlat0.y = dot(u_xlat2.xyz, u_xlat3.xyz);
    u_xlat0.xy = max(u_xlat0.xy, float2(0.0, 0.0));
    u_xlat0.x = log2(u_xlat0.x);
    u_xlat0.x = u_xlat0.x * FGlobals._Gloss;
    u_xlat0.x = exp2(u_xlat0.x);
    u_xlat1.xyz = _MainTex.sample(sampler_MainTex, input.TEXCOORD0.xy).xyz;
    u_xlat1.xyz = u_xlat1.xyz * FGlobals._Color.xyz;
    u_xlat2.xyz = u_xlat1.xyz * FGlobals.glstate_lightmodel_ambient.xyz;
    u_xlat1.xyz = u_xlat1.xyz * FGlobals._LightColor0.xyz;
    u_xlat2.xyz = u_xlat2.xyz + u_xlat2.xyz;
    u_xlat3.xyz = fma(u_xlat1.xyz, u_xlat0.yyy, u_xlat2.xyz);
    u_xlat1.xyz = FGlobals._LightColor0.xyz * FGlobals._Specular.xyz;
    output.SV_Target0.xyz = fma(u_xlat1.xyz, u_xlat0.xxx, u_xlat3.xyz);
    output.SV_Target0.w = 1.0;
    return output;
}


 }
}
Fallback "Specular"
}