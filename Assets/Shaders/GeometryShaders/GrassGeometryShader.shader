Shader "Geometry/GrassGeometryShader"
{
    Properties
    {


		_GrassTrample("Grass trample (XYZ -> Position, W -> Radius)", Vector) = (0,0,0,0)
		_GrassTrampleOffsetAmount("Grass trample offset amount", Range(0, 1)) = 0.2
        _Color("Color", Color) = (1,1,1,1)
        _GradientMap("Gradient map", 2D) = "white" {}
        _TessellationUniform ("Tessellation Uniform", Range(1, 64)) = 1
        _NoiseTexture("Noise texture", 2D) = "white" {} 
        _WindTexture("Wind texture", 2D) = "white" {}
        _WindForce("Wind Force", float) = 0
        _WindSpeed("Wind Speed", float) = 0
        _WindColor("Wind color", Color) = (1,1,1,1)
        _GrassHeight("Grass height", float) = 0
        _PositionRandomness("Position randomness", float) = 0
        _GrassWidth("Grass width", Range(0.0, 1.0)) = 1.0
        _GrassNumber("Grass blades per triangle", float) = 1

    }
    SubShader
    {

        CGINCLUDE
        
        #include "UnityCG.cginc"
        #include "CustomTessellation.cginc"
        #include "Autolight.cginc"

        struct appdata
        {
            float4 vertex : POSITION;
        };

        struct v2g
        {
            float4 vertex : POSITION;
        };

        struct g2f
        {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
            float4 col : COLOR;
            float3 normal : NORMAL;
            unityShadowCoord4 _ShadowCoord : TEXCOORD1;
            float3 viewDir : TEXCOORD2;
        };

        fixed4 _Color;
        sampler2D _GradientMap;
        
        sampler2D _NoiseTexture;
        float4 _NoiseTexture_ST;
        sampler2D _WindTexture;
        float4 _WindTexture_ST;
        float _WindForce;
        float _WindSpeed;
        fixed4 _WindColor;

        float _GrassHeight;
        float _GrassWidth;
        float _PositionRandomness;

        float _GrassNumber;
        float _MaxCameraDistance;

        float4 _GrassTrample;
        float _GrassTrampleOffsetAmount;
		float windPower;
		float _angle = 30;
        g2f GetClipPosVertex(float4 pos, float2 uv, fixed4 col, float3 normal) {
            g2f o;
            o.vertex = UnityObjectToClipPos(pos);
			o.viewDir = WorldSpaceViewDir(pos);
			o._ShadowCoord = ComputeScreenPos(o.vertex);
            o.uv = uv;
            o.col = col;
            o.normal = UnityObjectToWorldNormal(normal);
            return o;
        }

        float random (float2 st) {
            return frac(dot(st.xy, float2(cos(_angle), -sin(_angle))));
        }

        v2g vert (appdata v)
        {
            v2g o;
            o.vertex = v.vertex;
            return o;
        }

        [maxvertexcount(48)]
        void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
        {
            g2f o;
            int grassNumber = 8;
			float3 normal = normalize(cross(input[1].vertex - input[0].vertex, input[2].vertex - input[0].vertex));

            for (uint i = 0; i < grassNumber; i++) {
                float r1 = random(mul(unity_ObjectToWorld, input[1].vertex).xz * i );
                float r2 = random(mul(unity_ObjectToWorld, input[2].vertex).xz * i );

                float4 midpoint = (1 - sqrt(r1)) * input[0].vertex + (sqrt(r1) * (1 - r2)) * input[1].vertex + (sqrt(r1) * r2) * input[2].vertex;
                
                r1 = r1 * 2.0 - 1.0;
                r2 = r2 * 2.0 - 1.0;

                float4 pointA = midpoint + _GrassWidth * normalize(input[i % 3].vertex - midpoint);
                float4 pointB = midpoint - _GrassWidth * normalize(input[i % 3].vertex - midpoint);

                float4 worldPos = mul(unity_ObjectToWorld, pointA);

				float windPower =  sin(worldPos.x* r1 + worldPos.z *r2 + _Time.y * (1.2f + _WindForce/10.0f));

                float noise = tex2Dlod(_NoiseTexture, float4(worldPos.xz * _NoiseTexture_ST.xy, 0.0, 0.0)).x;
                float heightFactor = noise * _GrassHeight;  

				if (noise < 0.5)
					windPower = 0;

                triStream.Append(GetClipPosVertex(pointA, float2(0,0), fixed4(0,0,0,1), normal));

                float4 newVertexPoint = midpoint + float4(normal, 0.0) * heightFactor + float4(r1, 0.0, r2, 0.0) * _PositionRandomness + float4(windPower /20, 0.0, windPower /20, 0.0);

              //  float3 trampleDiff = mul(unity_ObjectToWorld, newVertexPoint).xyz + _GrassTrample.xyz;
                //float4 trampleOffset = float4(float3(normalize(trampleDiff).x, 0, normalize(trampleDiff).z) * (1.0 - saturate(length(trampleDiff) / _GrassTrample.w)) * random(worldPos), 0.0) * noise;

               // newVertexPoint += trampleOffset * _GrassTrampleOffsetAmount;
                float3 bladeNormal = normalize(cross(pointB.xyz - pointA.xyz, midpoint.xyz - newVertexPoint.xyz));

                triStream.Append(GetClipPosVertex(newVertexPoint, float2(0.5, 1), fixed4(1.0, length(windPower), 1.0, 1.0), bladeNormal));

                triStream.Append(GetClipPosVertex(pointB, float2(1,0), fixed4(0,0,0,1), normal));

                triStream.RestartStrip();
            }
        }

        ENDCG

        Pass
        {
            Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase" }
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma hull hull
			#pragma domain domain
            #pragma target 4.6
			#pragma multi_compile_fwdbase
            
			#include "Lighting.cginc"
                        
            float _RimPower;

            fixed4 frag (g2f i) : SV_Target
            {
                fixed4 gradientMapColor = tex2D(_GradientMap, float2(i.col.x, 0.0));
                fixed4 col =  (gradientMapColor + _WindColor * i.col.g) * _Color;
                float light = saturate(dot(normalize(_WorldSpaceLightPos0), i.normal)) * 0.5 + 0.5;
                fixed4 translucency = 1 * saturate(dot(normalize(-_WorldSpaceLightPos0), normalize(i.viewDir)));
                half rim =  pow(1.0 - saturate(dot(normalize(i.viewDir), i.normal)), _RimPower);
                float shadow = SHADOW_ATTENUATION(i);
                col *= (light + translucency * rim * i.col.x ) * _LightColor0 * shadow + float4( ShadeSH9(float4(i.normal, 1)), 1.0) ;
                return col;
            }
            
            ENDCG
        }

        Pass
        {
            Tags {
                "LightMode" = "ShadowCaster"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment fragShadow
            #pragma hull hull
			#pragma domain domain

            #pragma target 4.6
            #pragma multi_compile_shadowcaster

            float4 fragShadow(g2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }            
            
            ENDCG
        }

    }
}
