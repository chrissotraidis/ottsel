#pragma once
#include <algorithm>
#include <cmath>
#include <vector>

namespace ottsel_command_timing {
struct Sample { double submit, complete, gpu_start, gpu_end; bool success; };
struct Summary {
  unsigned completed=0, errors=0, invalid_cpu=0, invalid_gpu=0;
  double completion_hz=0, gpu_ms_p50=0, gpu_ms_p95=0, gpu_start_interval_ms_p95=0;
  bool completion_cadence_available=false, gpu_duration_available=false,
       gpu_interval_available=false;
};
inline double percentile(std::vector<double> values,double q) {
  std::sort(values.begin(),values.end());
  return values[size_t(std::ceil(q*values.size()))-1];
}
inline Summary summarize(const std::vector<Sample>& samples) {
  Summary s;std::vector<double> completions,durations,starts;
  for(const auto& sample:samples) {
    ++s.completed;
    if(!sample.success){++s.errors;continue;}
    if(!std::isfinite(sample.submit)||!std::isfinite(sample.complete)||
       sample.submit<=0||sample.complete<sample.submit)++s.invalid_cpu;
    else completions.push_back(sample.complete);
    if(!std::isfinite(sample.gpu_start)||!std::isfinite(sample.gpu_end)||
       sample.gpu_start<=0||sample.gpu_end<sample.gpu_start||
       !std::isfinite((sample.gpu_end-sample.gpu_start)*1000))++s.invalid_gpu;
    else {durations.push_back((sample.gpu_end-sample.gpu_start)*1000);starts.push_back(sample.gpu_start);}
  }
  std::sort(completions.begin(),completions.end());
  if(completions.size()>1&&completions.back()>completions.front()) {
    const double rate=(completions.size()-1)/(completions.back()-completions.front());
    if(std::isfinite(rate)){s.completion_cadence_available=true;s.completion_hz=rate;}
  }
  if(!durations.empty()) {
    s.gpu_duration_available=true;s.gpu_ms_p50=percentile(durations,.5);
    s.gpu_ms_p95=percentile(durations,.95);
  }
  std::sort(starts.begin(),starts.end());std::vector<double> intervals;
  for(size_t i=1;i<starts.size();++i)if(starts[i]>starts[i-1]&&std::isfinite((starts[i]-starts[i-1])*1000))intervals.push_back((starts[i]-starts[i-1])*1000);
  if(!intervals.empty()){s.gpu_interval_available=true;s.gpu_start_interval_ms_p95=percentile(intervals,.95);}
  return s;
}
}
