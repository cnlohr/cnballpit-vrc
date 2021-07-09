
using UnityEngine;
using VRC.SDKBase;

#if UDON
using UdonSharp;
using VRC.Udon;
#endif


public class DayNightControl : UdonSharpBehaviour
{
	[UdonSynced] public int LightMode = 0;
	const int NumLightModes = 3;
	public Light DirectionalLight;
	public Material SkyboxMaterial;
	public Material SkyboxMaterialNight;
	public Material WaterMaterial;
	public Material BallMaterial;
	public ReflectionProbe rprobe;

	// Start is called before the first frame update
	void UpdateLightMode()
	{
		switch( LightMode )
		{
			case 0:
				RenderSettings.skybox = SkyboxMaterial;
				DirectionalLight.transform.rotation = Quaternion.Euler( 164.79f, -286.73f, -20.39f );
				DirectionalLight.color = new Color( 1.0f, 0.9177405f, 0.6933962f, 1.0f );
				RenderSettings.ambientIntensity = 1.0f;
				SkyboxMaterial.SetFloat( "_AtmosphereThickness", 1.0f );
				WaterMaterial.SetFloat( "_Glossiness", 1.0f );
				BallMaterial.SetFloat( "_NightMode", 0 );
				BallMaterial.SetFloat( "_Smoothness", .77f );
				BallMaterial.SetFloat( "_Metallic", 0.0f );
				break;
			case 1:
				DirectionalLight.color = new Color( 0.1654503f, 0.1958628f, 0.245283f, 1.0f );
				//DirectionalLight.transform.rotation = Quaternion.Euler( 164.79f, -120.73f, -20.39f);
				DirectionalLight.transform.rotation = Quaternion.Euler( 70.0f, 0.0f, 0.0f );
				//SkyboxMaterial.SetFloat( "_AtmosphereThickness", 0.5f );
				RenderSettings.skybox = SkyboxMaterialNight;
				RenderSettings.ambientIntensity = 1.0f;
				WaterMaterial.SetFloat( "_Glossiness", 0.8f );
				BallMaterial.SetFloat( "_NightMode", 1 );
				BallMaterial.SetFloat( "_Smoothness", 1.0f );
				BallMaterial.SetFloat( "_Metallic", 0.0f );
				break;
			case 2:
				RenderSettings.skybox = SkyboxMaterial;
				DirectionalLight.color = new Color( 1.0f, 0.9177405f, 0.6933962f, 1.0f );
				DirectionalLight.transform.rotation = Quaternion.Euler( 0, 128, 0 );
				SkyboxMaterial.SetFloat( "_AtmosphereThickness", 1.0f );
				RenderSettings.ambientIntensity = 1.0f;
				WaterMaterial.SetFloat( "_Glossiness", 1.0f );
				BallMaterial.SetFloat( "_NightMode", 0 );
				BallMaterial.SetFloat( "_Smoothness", .77f );
				BallMaterial.SetFloat( "_Metallic", 0.0f );
				break;
			default:
				break;
		}
		rprobe.RenderProbe();
	}
	
	public void OnDeserialization()
	{
		UpdateLightMode();
	}
	
	void Start()
	{
		if( Networking.IsMaster )
		{
			LightMode = 1;
		}
		UpdateLightMode();
	}

	// Update is called once per frame
	void Interact()
	{
		if( Networking.IsMaster ) // ??? Why is this second one always 1? || Networking.IsInstanceOwner )
		{
			LightMode = ( LightMode + 1 ) % NumLightModes;
		}
		UpdateLightMode();
	}
}
