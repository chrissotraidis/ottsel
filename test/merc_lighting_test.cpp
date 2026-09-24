#include "mobile_merc_lighting.h"
#include <cassert>
#include <cstdio>
using namespace ottsel_mobile_merc_lighting;
int main(){
 NormalMatrix bones[2]{{{{1,0,0,0},{0,1,0,0},{0,0,1,0}}},{{{0,1,0,0},{-1,0,0,0},{0,0,1,0}}}};
 bool valid[2]={true,true};float nx[3]={1,0,0},nz[3]={0,0,1};float weights[3]={1,0,0};std::uint8_t slots[3]={0,255,255},rgba[4]={128,128,128,128};Color out{};
 Lights l{};l.directions[2][0]=1;for(int i=0;i<4;++i)l.ambient[i]=.25;l.colors[0][0]=.5;l.colors[0][1]=.25;l.colors[0][2]=.125;l.colors[0][3]=.5;
 auto near=[](float a,double b){assert(std::abs(a-b)<1e-6);};
 assert(shade(out,nz,weights,slots,bones,valid,2,l,rgba));near(out[0],128./255*.75);near(out[1],128./255*.5);near(out[2],128./255*.375);near(out[3],128./255*.75);
 // Rotation maps +X to +Y; transposed matrix would point -Y and lose lamp0.
 l.directions[2][0]=0;l.directions[1][0]=1;slots[0]=1;assert(shade(out,nx,weights,slots,bones,valid,2,l,rgba));near(out[0],128./255*.75);
 // Two perpendicular equally weighted normals normalize to (1,1,0)/sqrt2.
 slots[0]=0;slots[1]=1;weights[0]=weights[1]=.5;l.directions[0][0]=1;l.directions[1][0]=0;assert(shade(out,nx,weights,slots,bones,valid,2,l,rgba));near(out[0],128./255*(.25+.5/std::sqrt(2.)));
 // The direction vectors are columns, not independent per-lamp row vectors.
 weights[0]=1;weights[1]=0;slots[1]=255;l={};l.directions[0][0]=.25;l.directions[0][1]=.5;l.directions[0][2]=.75;l.colors[0][0]=1;l.colors[1][1]=1;l.colors[2][2]=1;l.ambient[3]=1;assert(shade(out,nx,weights,slots,bones,valid,2,l,rgba));near(out[0],128./255*.25);near(out[1],128./255*.5);near(out[2],128./255*.75);
 l.directions[0][0]=-1;assert(shade(out,nx,weights,slots,bones,valid,2,l,rgba));near(out[0],0);
 l={};l.ambient[0]=3;l.ambient[1]=2;l.ambient[2]=1;l.ambient[3]=.5;assert(shade(out,nx,weights,slots,bones,valid,2,l,rgba));near(out[0],384./255);assert(out[0]>1); // Must not quantize lit colors to RGBA8.
 float zero[3]{};assert(!shade(out,zero,weights,slots,bones,valid,2,l,rgba));
 puts("PASS proposed MERC lighting normal rotation, weighted normalization, direction layout, zero-weight slots and HDR color");
}
