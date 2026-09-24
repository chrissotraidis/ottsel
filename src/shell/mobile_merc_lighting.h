#pragma once
// Inputs are existing FR3 float normals, column-major
// packet nmat vectors, and the seven-qword VuLights at setup byte128.
#include <array>
#include <cmath>
#include <cstdint>
namespace ottsel_mobile_merc_lighting {
struct Lights { float directions[3][4]; float colors[3][4]; float ambient[4]; };
static_assert(sizeof(Lights)==112);
struct NormalMatrix { float nmat[3][4]; };
using Color=std::array<float,4>;
template<class Bone>
inline bool shade(Color& output,const float normal[3],const float weights[3],
                  const std::uint8_t slots[3],const Bone* matrices,
                  const bool* valid,std::size_t count,const Lights& lights,
                  const std::uint8_t rgba[4]) {
  float rotated[3]{};
  for(int influence=0;influence<3;++influence){
    // merc2.vert evaluates bone0 and skips later zero-weight garbage slots.
    if(influence && weights[influence]<=0)continue;
    const auto slot=slots[influence];
    if(slot>=count||!valid[slot])return false;
    for(int row=0;row<3;++row)for(int column=0;column<3;++column)
      rotated[row]+=matrices[slot].nmat[column][row]*normal[column]*weights[influence];
  }
  const float length=std::sqrt(rotated[0]*rotated[0]+rotated[1]*rotated[1]+rotated[2]*rotated[2]);
  if(!(length>0)||!std::isfinite(length))return false;
  for(float& component:rotated)component/=length;
  float intensity[3]{};
  for(int lamp=0;lamp<3;++lamp){
    for(int axis=0;axis<3;++axis)intensity[lamp]+=lights.directions[axis][lamp]*rotated[axis];
    if(intensity[lamp]<0)intensity[lamp]=0;
  }
  for(int channel=0;channel<4;++channel){
    float light=lights.ambient[channel];
    for(int lamp=0;lamp<3;++lamp)light+=intensity[lamp]*lights.colors[lamp][channel];
    output[channel]=(rgba[channel]/255.f)*light;
    if(!std::isfinite(output[channel]))return false;
  }
  return true;
}
}
