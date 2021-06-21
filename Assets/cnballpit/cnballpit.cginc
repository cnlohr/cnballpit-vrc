
texture2D< float4 > _PositionsIn;
texture2D< float4 > _VelocitiesIn;
texture2D< float2 > _AdjacencyMapIn;
texture2D< float2 > _AdjacencyMapInSecond;

float4 GetPosition( uint ballid )
{
	return _PositionsIn[uint2(ballid%1024,ballid/1024)];
}

float4 GetVelocity( uint ballid )
{
	return _VelocitiesIn[uint2(ballid%1024,ballid/1024)];
}

//Maps ???x???x??? to 4096x4096


#define ACTUALLY_DO_COMPLEX_HASH_FUNCTION 0
//The size of each hashed bucket.
static const float3 HashCellRange = float3( 17, 17, 17 );

uint2 Hash3ForAdjacency( int3 rlcoord )
{
	//This may be a heavy handed hash algo.  It's currently 8 instructions.
	// Thanks, @D4rkPl4y3r for suggesting the hash buckets.

#if ACTUALLY_DO_COMPLEX_HASH_FUNCTION
	static const uint3 xva = uint3( 7919, 1046527, 37633 );
	static const uint3 xvb = uint3( 756839, 3343, 19937 );
	uint3 rlc = uint3( rlcoord );
	uint3 hva = xva * rlc;
	uint3 hvb = xvb * rlc;
	return uint2( hva.x+hva.y+hva.z, hvb.x+hvb.y+hvb.z) % 4096;
#else
	return uint2( rlcoord.x + (rlcoord.z%8)*256, rlcoord.y + (rlcoord.z/8)*128 ) % 4096;

#endif
}