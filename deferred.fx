////////////////////////////////////////////////////////////////////////////////////////////////
//
//  full.fx ver1.4_1
//  �쐬: ���͉��P
//  ������: 2012/05/01
//
//  MME�X���̕��͉��P���̏������Ƃ�beat32lop������
//
////////////////////////////////////////////////////////////////////////////////////////////////
// �p�����[�^�錾

// ���@�ϊ��s��
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// �}�e���A���F
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
float4 EgColor;

// ���C�g�F
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // �p�[�X�y�N�e�B�u�t���O
bool     transp;   // �������t���O
bool	 spadd;    // �X�t�B�A�}�b�v���Z�����t���O
#define SKII1    1500
#define SKII2    8000
#define Toon     3

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;

// �I�u�W�F�N�g�̃e�N�X�`��
//texture ObjectTexture: MATERIALTEXTURE;
//sampler ObjTexSampler = sampler_state {
//    texture = <ObjectTexture>;
//    MINFILTER = LINEAR;
//    MAGFILTER = LINEAR;
//};
//
//// �X�t�B�A�}�b�v�̃e�N�X�`��
//texture ObjectSphereMap: MATERIALSPHEREMAP;
//sampler ObjSphareSampler = sampler_state {
//    texture = <ObjectSphereMap>;
//    MINFILTER = LINEAR;
//    MAGFILTER = LINEAR;
//};

// G-Buffer
texture G_Position : OFFSCREENRENDERTARGET <
    string Description = "Position buffer";
    float4 ClearColor = {0, 0, 0, 0};
    float ClearDepth = 1.0;
    float2 ViewportRatio = {1.0, 1.0};
    string Format = "D3DFMT_A16B16G16R16F";
    string DefaultEffect = 
        "self = hide;"
        "*.pmd = g_position.fxsub;"
        "*.pmx = g_position.fxsub;"
        "*.x = hide;"
        "* = hide;" ;
>;
sampler G_PositionSampler = sampler_state {
    texture = <G_Position>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture G_Normal : OFFSCREENRENDERTARGET <
    string Description = "Normal buffer";
    float4 ClearColor = {0, 0, 0, 0};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A16B16G16R16F";
    string DefaultEffect = 
        "self = hide;"
        "*.pmd = g_normal.fxsub;"
        "*.pmx = g_normal.fxsub;"
        "*.x = hide;"
        "* = hide;" ;
>;
sampler G_NormalSampler = sampler_state {
    texture = <G_Normal>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture G_AlbedoSpec : OFFSCREENRENDERTARGET <
    string Description = "Albedo-Specular buffer";
    float4 ClearColor = {0, 0, 0, 0};
    float ClearDepth = 1.0;
    string Format = "D3DFMT_A16B16G16R16F";
    string DefaultEffect = 
        "self = hide;"
        "*.pmd = g_albedospec.fxsub;"
        "*.pmx = g_albedospec.fxsub;"
        "*.x = hide;"
        "* = hide;" ;
>;
sampler G_AlbedoSpecSampler = sampler_state {
    texture = <G_AlbedoSpec>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// MMD�{����sampler���㏑�����Ȃ����߂̋L�q�ł��B�폜�s�B
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

struct VS_OUTPUT {
    float4 Pos			: POSITION;
    float2 Tex			: TEXCOORD0;
};

// ���_�V�F�[�_
VS_OUTPUT VS_ScreenTex( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

// �s�N�Z���V�F�[�_
float4 PS_ScreenTex( float2 Tex: TEXCOORD0 ) : COLOR
{
    float3 FragPos = tex2D(G_PositionSampler, Tex).rgb;
    float3 N = tex2D(G_NormalSampler, Tex).rgb;
    float4 AlbedoSpec = tex2D(G_AlbedoSpecSampler, Tex);
    float3 Diffuse = AlbedoSpec.rgb;
    float Pow = AlbedoSpec.a;

    float3 V = normalize(CameraPosition - FragPos);
    float L = LightDirection;

    float3 diffuse = max(dot(N, L), 0) * Diffuse * LightDiffuse;
    float3 H = normalize(L + V);
    float spec = pow(max(dot(N, H), 0), Pow);
    float3 specular = LightSpecular * spec;

    // �e�N�X�`���K�p
    float4 Color = float4(diffuse, 1);
    return Color;
}

float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;
// Draw quad
technique ScreenTexTech <
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color;"
            "Clear=Depth;"
            "ScriptExternal=Color;"
	    "Pass=ScreenTexPass;";
> {
    pass ScreenTexPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_2_0 VS_ScreenTex();
        PixelShader  = compile ps_2_0 PS_ScreenTex();
    }
}


