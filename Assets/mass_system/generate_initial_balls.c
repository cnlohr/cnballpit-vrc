#include "unitytexturewriter.h"
#include <stdio.h>

int main()
{
	float asset3d[32][32][32][4] = {0};
	int x, y, z;
	for( z = 0; z < 50; z++ )
	for( y = 0; y < 50; y++ )
	for( x = 0; x < 50; x++ )
	{
		float lx = (x - 25.)/25. + sin(z*.1)*.5;
		float ly = (y - 25.)/25. + cos(z*.1)*.5;
		float lz = cos(z*.1);
		float col = 1.-sqrt(lx*lx+ly*ly+lz*lz);
		asset3d[z][y][x][0] = col-10;
		asset3d[z][y][x][1] = col;
		asset3d[z][y][x][2] = col-20;
		asset3d[z][y][x][3] = 255;
	}
	WriteUnityImageAsset( "test3d.asset", asset3d, sizeof(asset3d), 50, 50, 50, UTE_RGBA_FLOAT | UTE_FLAG_IS_3D );
	
}