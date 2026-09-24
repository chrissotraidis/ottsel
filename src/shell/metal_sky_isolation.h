#pragma once
// One explicit Training capture, five fragment variants. Included after NativeSpriteBatch.
struct SkyIsolationProbe : std::enable_shared_from_this<SkyIsolationProbe> {
  id<MTLDevice> device;
  MTLRenderPipelineDescriptor* plain;
  MTLRenderPipelineDescriptor* blend;
  NSString* source;
  id<MTLRenderPipelineState> pipelines[5]{};
  NativeSpriteBatch frozen;
  struct PopulationEntry {NativeSpriteBatch batch;id<MTLDepthStencilState> depth;uint64_t vertices_hash,texture_hash;};
  std::vector<PopulationEntry> population;
  id<MTLRenderPipelineState> population_pipelines[2]{};
  bool population_mode=false;
  NSUInteger prefix_count=0;
  unsigned prefix_steps=0;
  size_t readback_total=0;
  uint64_t population_hash=1469598103934665603ull;
  static constexpr size_t kPopulationVertices=4*1024*1024,kPopulationTextures=16*1024*1024,kReadbackTotal=64*1024*1024;
  id<MTLTexture> known,depth;
  id<MTLSamplerState> sampler;
  id<MTLDepthStencilState> depth_state;
  unsigned material[6]{0,0,0,1,0,0};
  NSUInteger width=0,height=0,batch_index=0;
  uint64_t vertex_hash=0,texture_hash=0;
  unsigned variant=0;
  bool consumed=false,captured=false,readback_pending=false;
  std::atomic<int> completed{-1};
  std::atomic<bool> failed{false},timed_out{false};
  std::string directory;
  static constexpr unsigned kSequenceTimeoutSeconds=120;
  static uint64_t hash(const void* bytes,size_t length) {
    auto p=static_cast<const unsigned char*>(bytes);uint64_t h=1469598103934665603ull;
    for(size_t i=0;i<length;++i){h^=p[i];h*=1099511628211ull;}return h;
  }
  void abort(const char* reason) {
    failed=true;NSLog(@"OTTSEL SKY ISOLATION: ABORT reason=%s variant=%u",reason,variant);
  }
  bool activeRequest() const {
    if (consumed) {
      return false;
    }
    // L3 (2026-09-22): this ran two access() calls on every present (the main thread's present path) for a
    // diagnostic whose trigger only appears when a driver asks for a capture.  Poll every sixteenth call and
    // memoise, so a request is still noticed within a fraction of a second while the steady-state present
    // path stops stat()-ing the container.  The memo is stable across the caller's check-then-capture pair.
    static unsigned s_poll_counter = 0;
    static bool s_poll_result = false;
    if ((s_poll_counter++ % 16u) == 0) {
      s_poll_result = access((directory+"ottsel-sky-isolation-training").c_str(),F_OK)==0 ||
        access((directory+"ottsel-sky-population-training").c_str(),F_OK)==0;
    }
    return s_poll_result;
  }
  bool capture(const std::vector<NativeSpriteBatch>& batches,id<MTLTexture> drawable,
               id<MTLSamplerState> original_sampler,
               id<MTLDepthStencilState> (^select_depth)(const NativeSpriteBatch&)) {
    if(!activeRequest())return false;
    consumed=true;
    population_mode=access((directory+"ottsel-sky-population-training").c_str(),F_OK)==0;
    const std::string request_path=directory+(population_mode?"ottsel-sky-population-training":"ottsel-sky-isolation-training");
    FILE* request=fopen(request_path.c_str(),"r");
    unsigned requested=0;const bool parsed=request&&fscanf(request,"%u",&requested)==1;
    if(request)fclose(request);unlink(request_path.c_str());
    if(!parsed||requested>=batches.size()||(population_mode&&(requested!=0||batches.size()>64))){abort("invalid-exact-batch-index");return false;}
    if(drawable.pixelFormat!=MTLPixelFormatBGRA8Unorm){abort("unsupported-drawable-format");return false;}
    batch_index=requested;const auto& batch=batches[batch_index];
    width=drawable.width;height=drawable.height;
    const size_t vertex_bytes=batch.vertex_count*sizeof(OttselMetalSpriteVertex);
    const size_t texture_bytes=batch.texture.width*batch.texture.height*4;
    if(!batch.vertex_count||vertex_bytes>4*1024*1024||vertex_bytes>batch.vertices.length||
       !batch.vertices.contents||!batch.texture||batch.texture.pixelFormat!=MTLPixelFormatRGBA8Unorm||
       batch.texture.storageMode!=MTLStorageModeShared||!texture_bytes||texture_bytes>16*1024*1024||
       !width||!height||width*height*4>16*1024*1024) {abort("unsupported-capture-layout-or-budget");return false;}
    std::vector<unsigned char> pixels(texture_bytes);
    [batch.texture getBytes:pixels.data() bytesPerRow:batch.texture.width*4
                   fromRegion:MTLRegionMake2D(0,0,batch.texture.width,batch.texture.height) mipmapLevel:0];
    frozen=batch;
    frozen.vertices=[device newBufferWithBytes:batch.vertices.contents length:vertex_bytes options:MTLResourceStorageModeShared];
    auto td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
             width:batch.texture.width height:batch.texture.height mipmapped:NO];
    td.storageMode=MTLStorageModeShared;td.usage=MTLTextureUsageShaderRead;
    frozen.texture=[device newTextureWithDescriptor:td];
    [frozen.texture replaceRegion:MTLRegionMake2D(0,0,td.width,td.height) mipmapLevel:0 withBytes:pixels.data() bytesPerRow:td.width*4];
    td.width=2;td.height=2;known=[device newTextureWithDescriptor:td];
    const unsigned char checker[16]={255,0,0,255,0,255,0,255,0,0,255,255,255,255,255,255};
    [known replaceRegion:MTLRegionMake2D(0,0,2,2) mipmapLevel:0 withBytes:checker bytesPerRow:8];
    auto dd=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:width height:height mipmapped:NO];
    dd.storageMode=MTLStorageModePrivate;dd.usage=MTLTextureUsageRenderTarget;depth=[device newTextureWithDescriptor:dd];
    sampler=original_sampler;depth_state=select_depth(batch);material[5]=batch.ta0;
    if(!frozen.vertices||!frozen.texture||!known||!depth||!sampler||!depth_state){abort("capture-allocation");return false;}
    vertex_hash=hash(frozen.vertices.contents,vertex_bytes);texture_hash=hash(pixels.data(),pixels.size());
    NSString* extra=@"\nfragment float4 isolation_constant(DirectOut in [[stage_in]]) { return float4(1,0,1,1); }\n"
      "fragment float4 isolation_uv(DirectOut in [[stage_in]]) { return float4(fract(direct_uv(in)),0,1); }\n"
      "fragment float4 isolation_tex(DirectOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler s [[sampler(0)]]) { return float4(tex.sample(s,direct_uv(in)).rgb,1); }\n";
    NSError* error=nil;auto library=[device newLibraryWithSource:[source stringByAppendingString:extra] options:nil error:&error];
    if(!library){abort("shader-library-compilation");NSLog(@"%@",error);return false;}
    NSArray<NSString*>* names=@[@"isolation_constant",@"isolation_uv",@"isolation_tex",@"isolation_tex",@"direct_fs"];
    for(unsigned i=0;i<5;++i){MTLRenderPipelineDescriptor* pd=[(batch.blended?blend:plain) copy];pd.fragmentFunction=[library newFunctionWithName:names[i]];pipelines[i]=[device newRenderPipelineStateWithDescriptor:pd error:&error];if(!pipelines[i]){abort("pipeline-compilation");NSLog(@"%@",error);return false;}}
    const auto write=[&](const char* name,const void* data,size_t size){FILE* f=fopen((directory+name).c_str(),"wb");if(!f)return false;bool ok=fwrite(data,1,size,f)==size;ok=fclose(f)==0&&ok;return ok;};
    if(!write("ottsel-sky-isolation-vertices.bin",frozen.vertices.contents,vertex_bytes)||
       !write("ottsel-sky-isolation-texture.rgba",pixels.data(),pixels.size())){abort("capture-artifact-write");return false;}
    NSLog(@"OTTSEL SKY ISOLATION: capture=1 batch=%lu vertices=%lu vertex-hash=%016llx tex=%lux%lu texture-hash=%016llx "
      "viewport=%lux%lu blend=%d has-depth=%d test=%llx zbuf=%llx material=0,0,0,1,0,%u depth-clear=0 fixed-pass=after-product",
      (unsigned long)batch_index,(unsigned long)batch.vertex_count,vertex_hash,(unsigned long)batch.texture.width,
      (unsigned long)batch.texture.height,texture_hash,(unsigned long)width,(unsigned long)height,batch.blended,batch.has_gs_depth,
      batch.depth.test,batch.depth.zbuf,material[5]);
    if(population_mode && !capturePopulation(batches,select_depth,library))return false;
    captured=true;const auto state=shared_from_this();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,int64_t(kSequenceTimeoutSeconds)*NSEC_PER_SEC),dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{state->timed_out=true;});
    return true;
  }
  bool capturePopulation(const std::vector<NativeSpriteBatch>& batches,
                        id<MTLDepthStencilState> (^select_depth)(const NativeSpriteBatch&),
                        id<MTLLibrary> library) {
    size_t vertices_total=0,textures_total=0;
    for(const auto& b:batches) {
      if(!b.vertices.contents||!b.vertex_count||b.vertex_count>kPopulationVertices/sizeof(OttselMetalSpriteVertex)||
         b.vertex_count*sizeof(OttselMetalSpriteVertex)>b.vertices.length||!b.texture||
         b.texture.pixelFormat!=MTLPixelFormatRGBA8Unorm||b.texture.storageMode!=MTLStorageModeShared||
         !b.texture.width||!b.texture.height||b.texture.width>kPopulationTextures/4/b.texture.height){abort("population-layout");return false;}
      vertices_total+=b.vertex_count*sizeof(OttselMetalSpriteVertex);textures_total+=b.texture.width*b.texture.height*4;
      if(vertices_total>kPopulationVertices||textures_total>kPopulationTextures){abort("population-memory-budget");return false;}
    }
    NSError* error=nil;
    for(unsigned i=0;i<2;++i){MTLRenderPipelineDescriptor* pd=[(i?blend:plain) copy];
      pd.fragmentFunction=[library newFunctionWithName:@"direct_fs"];
      population_pipelines[i]=[device newRenderPipelineStateWithDescriptor:pd error:&error];
      if(!population_pipelines[i]){abort("population-pipeline");return false;}}
    FILE* ledger=fopen((directory+"ottsel-sky-population-ledger.txt").c_str(),"w");
    if(!ledger){abort("population-ledger");return false;}
    fprintf(ledger,"capture=1 count=%lu viewport=%lux%lu vertices_bytes=%zu texture_bytes=%zu material=0,0,0,1,0,TA0 depth-clear=0 final-isolated-pass=1\n",(unsigned long)batches.size(),(unsigned long)width,(unsigned long)height,vertices_total,textures_total);
    for(NSUInteger i=0;i<batches.size();++i) {
      const auto& original=batches[i];NativeSpriteBatch copy=original;
      const size_t vb=original.vertex_count*sizeof(OttselMetalSpriteVertex),tb=original.texture.width*original.texture.height*4;
      std::vector<unsigned char> pixels(tb);
      [original.texture getBytes:pixels.data() bytesPerRow:original.texture.width*4 fromRegion:MTLRegionMake2D(0,0,original.texture.width,original.texture.height) mipmapLevel:0];
      if(i==batch_index)copy=frozen;
      else {
        copy.vertices=[device newBufferWithBytes:original.vertices.contents length:vb options:MTLResourceStorageModeShared];
        auto td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:original.texture.width height:original.texture.height mipmapped:NO];
        td.storageMode=MTLStorageModeShared;td.usage=MTLTextureUsageShaderRead;copy.texture=[device newTextureWithDescriptor:td];
        [copy.texture replaceRegion:MTLRegionMake2D(0,0,td.width,td.height) mipmapLevel:0 withBytes:pixels.data() bytesPerRow:td.width*4];
      }
      auto ds=select_depth(original);
      if(!copy.vertices||!copy.texture||!ds){fclose(ledger);abort("population-allocation");return false;}
      const auto vh=hash(copy.vertices.contents,vb),th=hash(pixels.data(),tb);
      population.push_back({copy,ds,vh,th});
      const uint64_t identity[]={uint64_t(i),vh,th,copy.depth.test,copy.depth.zbuf,copy.diagnostic_alpha,copy.ta0,uint64_t(copy.blended)};
      population_hash^=hash(identity,sizeof(identity));population_hash*=1099511628211ull;
      const auto* v=static_cast<const OttselMetalSpriteVertex*>(copy.vertices.contents);
      float lo[5]={v[0].color[0],v[0].color[1],v[0].color[2],v[0].color[3],v[0].z};float hi[5];memcpy(hi,lo,sizeof(lo));
      for(NSUInteger j=0;j<copy.vertex_count;++j)for(unsigned k=0;k<5;++k){const float value=k==4?v[j].z:v[j].color[k];lo[k]=std::min(lo[k],value);hi[k]=std::max(hi[k],value);}
      fprintf(ledger,"batch=%lu vertices=%lu vertex_hash=%016llx texture=%lux%lu texture_hash=%016llx blend=%d hasdepth=%d TEST=%llx ZBUF=%llx ALPHA=%llx TA0=%u rgba_z_min=%g,%g,%g,%g,%g max=%g,%g,%g,%g,%g\n",
        (unsigned long)i,(unsigned long)copy.vertex_count,vh,(unsigned long)copy.texture.width,(unsigned long)copy.texture.height,th,copy.blended,copy.has_gs_depth,copy.depth.test,copy.depth.zbuf,copy.diagnostic_alpha,copy.ta0,lo[0],lo[1],lo[2],lo[3],lo[4],hi[0],hi[1],hi[2],hi[3],hi[4]);
      for(unsigned part=0;part<2;++part){char name[96];snprintf(name,sizeof(name),"ottsel-sky-population-%lu-%s.bin",(unsigned long)i,part?"texture":"vertices");FILE* f=fopen((directory+name).c_str(),"wb");if(!f){fclose(ledger);abort("population-artifact");return false;}
        const size_t size=part?tb:vb;const void* data=part?static_cast<const void*>(pixels.data()):copy.vertices.contents;
        const bool written=fwrite(data,1,size,f)==size;const bool closed=fclose(f)==0;if(!written||!closed){fclose(ledger);abort("population-artifact-write");return false;}}
    }
    fprintf(ledger,"population_hash=%016llx\n",population_hash);
    const bool ok=!ferror(ledger);const bool closed=fclose(ledger)==0;if(!ok||!closed){abort("population-ledger-write");return false;}
    NSLog(@"OTTSEL SKY POPULATION: capture=1 batches=%lu vertex-bytes=%lu texture-bytes=%lu ALPHA=diagnostic-only",(unsigned long)population.size(),(unsigned long)vertices_total,(unsigned long)textures_total);
    return true;
  }
  void encode(id<MTLCommandBuffer> cb,id<MTLTexture> drawable) {
    if(!captured||failed)return;
    if(timed_out){abort("120s-sequence-timeout");captured=false;return;}
    if(drawable.pixelFormat!=MTLPixelFormatBGRA8Unorm){abort("drawable-format-changed");return;}
    if(width!=drawable.width||height!=drawable.height){abort("drawable-size-changed");return;}
    if(completed.load()==int(variant)) {
      const auto prefix_path=directory+"ottsel-sky-isolation-prefix";
      if(population_mode && variant>=1 && access(prefix_path.c_str(),F_OK)==0) {
        FILE* f=fopen(prefix_path.c_str(),"r");unsigned n=0;const bool valid=f&&fscanf(f,"%u",&n)==1;
        if(f)fclose(f);unlink(prefix_path.c_str());
        if(!valid||!n||n>population.size()||++prefix_steps>64){abort("invalid-prefix-or-prefix-budget");return;}
        prefix_count=n;variant=2+prefix_steps;readback_pending=false;
      } else if(unlink((directory+"ottsel-sky-isolation-next").c_str())==0) {
        if((population_mode&&variant!=0)||(!population_mode&&variant==4)){NSLog(@"OTTSEL SKY ISOLATION: sequence finished; normal composition separate");captured=false;return;}
        ++variant;readback_pending=false;
      }
    }
    if(hash(frozen.vertices.contents,frozen.vertex_count*sizeof(OttselMetalSpriteVertex))!=vertex_hash){abort("frozen-vertices-mutated");return;}
    auto pass=[MTLRenderPassDescriptor renderPassDescriptor];pass.colorAttachments[0].texture=drawable;
    pass.colorAttachments[0].loadAction=MTLLoadActionClear;pass.colorAttachments[0].storeAction=MTLStoreActionStore;
    pass.colorAttachments[0].clearColor=MTLClearColorMake(.08,.08,.08,1);
    pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction=MTLLoadActionClear;
    pass.depthAttachment.storeAction=MTLStoreActionDontCare;pass.depthAttachment.clearDepth=0;
    auto enc=[cb renderCommandEncoderWithDescriptor:pass];if(!enc){abort("encoder-allocation");return;}
    RenderEncoderEndGuard guard(enc);
    const MTLViewport viewport={0,0,double(width),double(height),0,1};
    const MTLScissorRect scissor={0,0,width,height};
    [enc setViewport:viewport];[enc setScissorRect:scissor];[enc setCullMode:MTLCullModeNone];
    if(population_mode) {
      const NSUInteger count=variant==0?1:(variant==1?population.size():prefix_count);
      for(NSUInteger i=0;i<count;++i) {
        const auto& entry=population[i];const auto& batch=entry.batch;
        if(hash(batch.vertices.contents,batch.vertex_count*sizeof(OttselMetalSpriteVertex))!=entry.vertices_hash){abort("population-vertices-mutated");return;}
        unsigned state[6]={0,0,0,1,0,batch.ta0};
        [enc setRenderPipelineState:population_pipelines[batch.blended?1:0]];[enc setDepthStencilState:entry.depth];
        [enc setVertexBuffer:batch.vertices offset:0 atIndex:0];[enc setFragmentTexture:batch.texture atIndex:0];
        [enc setFragmentSamplerState:sampler atIndex:0];[enc setFragmentBytes:state length:sizeof(state) atIndex:1];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:batch.vertex_count];
      }
    } else {
    [enc setRenderPipelineState:pipelines[variant]];[enc setDepthStencilState:depth_state];
    [enc setVertexBuffer:frozen.vertices offset:0 atIndex:0];
    [enc setFragmentTexture:variant==2?known:frozen.texture atIndex:0];
    [enc setFragmentSamplerState:sampler atIndex:0];[enc setFragmentBytes:material length:sizeof(material) atIndex:1];
    [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:frozen.vertex_count];
    }
    guard.end();
    if(readback_pending)return;
    const NSUInteger row_bytes=(width*4+255)&~NSUInteger(255);
    if(row_bytes*height>16*1024*1024||row_bytes*height>kReadbackTotal-readback_total){abort("readback-budget");return;}
    auto rb=[device newBufferWithLength:row_bytes*height options:MTLResourceStorageModeShared];
    auto blit=[cb blitCommandEncoder];if(!rb||!blit){if(blit)[blit endEncoding];abort("readback-allocation");return;}
    memset(rb.contents,0,row_bytes*height);
    [blit copyFromTexture:drawable sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0,0,0)
      sourceSize:MTLSizeMake(width,height,1) toBuffer:rb destinationOffset:0 destinationBytesPerRow:row_bytes destinationBytesPerImage:row_bytes*height];[blit endEncoding];
    readback_total+=row_bytes*height;
    NSLog(@"OTTSEL SKY POPULATION: capture=1 variant=%u prefix=%lu population=%lu population-hash=%016llx total-readback=%lu",variant,(unsigned long)(variant==0?1:(variant==1?population.size():prefix_count)),(unsigned long)population.size(),population_hash,(unsigned long)readback_total);
    readback_pending=true;const auto state=shared_from_this();const auto current=variant;
    [cb addCompletedHandler:^(id<MTLCommandBuffer> completed_cb){
      if(completed_cb.status!=MTLCommandBufferStatusCompleted||completed_cb.error){state->failed=true;NSLog(@"OTTSEL SKY ISOLATION: CB-error variant=%u %@",current,completed_cb.error);return;}
      char name[80];snprintf(name,sizeof(name),"ottsel-sky-isolation-%u.ppm",current);
      FILE* f=fopen((state->directory+name).c_str(),"wb");if(!f){state->failed=true;return;}
      fprintf(f,"P6\n%lu %lu\n255\n",(unsigned long)state->width,(unsigned long)state->height);
      const auto* p=static_cast<const unsigned char*>(rb.contents);
      for(NSUInteger y=0;y<state->height;++y)for(NSUInteger x=0;x<state->width;++x){const auto* pixel=p+y*row_bytes+x*4;fputc(pixel[2],f);fputc(pixel[1],f);fputc(pixel[0],f);}
      const bool ok=!ferror(f);const bool closed=fclose(f)==0;if(!ok||!closed){state->failed=true;return;}
      NSLog(@"OTTSEL SKY ISOLATION: CB-complete capture=1 variant=%u batch=%lu vertex-hash=%016llx texture-hash=%016llx readback-hash=%016llx file=%s",
        current,(unsigned long)state->batch_index,state->vertex_hash,state->texture_hash,SkyIsolationProbe::hash(rb.contents,row_bytes*state->height),name);
      state->completed=int(current);
    }];
  }
};
