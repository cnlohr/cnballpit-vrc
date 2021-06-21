
texture2D< float4 > _PositionsIn;
texture2D< float4 > _VelocitiesIn;
texture2D< float > _Adjacency0;
texture2D< float > _Adjacency1;
texture2D< float > _Adjacency2;

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
#define ACTUALLY_DO_COMPLEX_HASH_FUNCTION 0
//The size of each hashed bucket.

static const float3 HashCellRange = float3( 12, 12, 12 );

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
	return uint2( hva.x+hva.y+hva.z, hvb.x+hvb.y+hvb.z) % 2048;
#else

	return uint2( rlcoord.x + (rlcoord.z%8)*136, rlcoord.y + (rlcoord.z/8)*64 ) % 2048;
#endif
}