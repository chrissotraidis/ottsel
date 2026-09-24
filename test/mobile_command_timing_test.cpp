#include "mobile_command_timing.h"
#include <cassert>
#include <limits>
using namespace ottsel_command_timing;
int main(){
 auto empty=summarize({});assert(!empty.completion_cadence_available&&!empty.gpu_duration_available);
 auto good=summarize({{1,1.02,1.001,1.003,true},{1.03,1.04,1.031,1.033,true}});
 assert(good.completed==2&&good.errors==0&&good.completion_cadence_available);
 assert(std::abs(good.completion_hz-50)<1e-8&&std::abs(good.gpu_ms_p95-2)<1e-8);
 assert(std::abs(good.gpu_start_interval_ms_p95-30)<1e-8);
 auto invalid=summarize({{2,1,0,0,true},{1,2,std::numeric_limits<double>::quiet_NaN(),3,true},{1,2,3,2,true},{1,2,1,2,false}});
 assert(invalid.completed==4&&invalid.errors==1&&invalid.invalid_cpu==1&&invalid.invalid_gpu==3);
 assert(!invalid.gpu_duration_available&&!invalid.gpu_interval_available);
 auto huge=summarize({{1,2,1,std::numeric_limits<double>::max(),true}});
 assert(huge.invalid_gpu==1&&!huge.gpu_duration_available);
 auto duplicates=summarize({{1,2,1,1,true},{1,2,1,1,true}});
 assert(!duplicates.completion_cadence_available&&!duplicates.gpu_interval_available);
}
