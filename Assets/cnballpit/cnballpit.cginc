
texture2D< float4 > _PositionsIn;
texture2D< float4 > _VelocitiesIn;
texture2D< float4 > _Adjacency0;
texture2D< float4 > _Adjacency1;
texture2D< float4 > _Adjacency2;
texture2D< float4 > _Adjacency3;

float4 _PositionsIn_TexelSize;
float4 _VelocitiesIn_TexelSize;
float4 _Adjacency0_TexelSize;
float4 _Adjacency1_TexelSize;
float4 _Adjacency2_TexelSize;
float4 _Adjacency3_TexelSize;

float4 GetPosition( uint ballid )
{
	return _PositionsIn[uint2(ballid%1024,ballid/1024)];
}

float4 GetVelocity( uint ballid )
{
	return _VelocitiesIn[uint2(ballid%1024,ballid/1024)];
}

//NOTE BY CNL: Doing a hash appears to peform much worse than
// a procedural path, not in speed (though that's true) but it gets worse collisions.
#define ACTUALLY_DO_COMPLEX_HASH_FUNCTION 1
//The size of each hashed bucket.

//@ .9 -> Tested: 9 is good, 8 oooccasssionallyyy tweaks.  10 is cruising.
//@ .8 -> Tested: 10 is almost perfect ... switch to 11 (if on 10M edge cube)
//@ .8 -> Tested: 9 is almost perfect on cylinder... But needs to be 10.
static const float3 HashCellRange = float3( 10, 10, 10);
static const int SearchExtents = 2;
static const float SeachExtentsRange = 2.45; //2.4 NOT OK; 2.45 OK. (range of 6) ... Setting to range of sqrt(7) to be safe.

uint2 Hash3ForAdjacency( float3 rlcoord )
{
	//This may be a heavy handed hash algo.  It's currently 8 instructions.
	// Thanks, @D4rkPl4y3r for suggesting the hash buckets.

#if ACTUALLY_DO_COMPLEX_HASH_FUNCTION
	static const uint3 xva = uint3( 7919, 1046527, 37633 );
	static const uint3 xvb = uint3( 7569, 334, 19937 );
	uint3 rlc = uint3( rlcoord * HashCellRange + HashCellRange * 100 );
	uint3 hva = xva * rlc;
	uint3 hvb = xvb * rlc;
	return uint2( hva.x+hva.y+hva.z, hvb.x+hvb.y+hvb.z) % 1024;
#else
	uint3 normcoord = int3(rlcoord*HashCellRange + HashCellRange * 10);
	return uint2( normcoord.x + (normcoord.z%8)*120, normcoord.y + (normcoord.z/8)*64 ) % 1024;
#endif
}