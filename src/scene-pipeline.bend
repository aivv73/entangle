import Base
import ./scene-texture.bend as T
import ./content.bend as F
import ../deps/bend-vulkan/Vulkan.bend as V
import ../deps/bend-vulkan/src/constants.bend as vk
import ../deps/bend-vulkan/shaders/spirv.bend as Basic
import ./shaders/spirv.bend as Lit

type Pipelines is Data:
  Pipelines{basic:V.GraphicsPipeline,basic_layout:V.PipelineLayout,textured:V.GraphicsPipeline,textured_layout:V.PipelineLayout,schema:V.DescriptorSetLayout}

def attributes(textured:Bool) -> List<V.VertexInputAttribute>:
  List.append(&1,V.VertexInputAttribute,[V.VertexInputAttribute{0,0,vk.VK_FORMAT_R32G32B32_SFLOAT(),0},V.VertexInputAttribute{1,0,vk.VK_FORMAT_R32G32B32_SFLOAT(),12}],
    Bool.pick(List<V.VertexInputAttribute>,textured,[V.VertexInputAttribute{2,0,vk.VK_FORMAT_R32G32_SFLOAT(),24},V.VertexInputAttribute{3,0,vk.VK_FORMAT_R32G32B32_SFLOAT(),32}],[]))

def pipeline(+device:V.Device,pass:V.RenderPass,layout:V.PipelineLayout,front:U32,cull:U32,+textured:Bool) -> V.Action(V.GraphicsPipeline):
  do V.Action<V.GraphicsPipeline>:
    +vertex:V.ShaderModule <- V.Device.create_shader_module(device,Bool.pick(List<U32>,textured,Lit.vert(),Basic.vertex_words()))
    +fragment:V.ShaderModule <- V.Device.create_shader_module(device,Bool.pick(List<U32>,textured,Lit.frag(),Basic.fragment_words()))
    pipeline:V.GraphicsPipeline <- V.Device.create_graphics_pipeline(device,V.GraphicsPipelineCreateInfo{layout,pass,vertex,fragment,[V.VertexInputBinding{0,F.vertex_stride(),vk.VK_VERTEX_INPUT_RATE_VERTEX()}],attributes(textured),vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST(),V.RasterState{cull,front},Some{V.DepthState{True{},True{},vk.VK_COMPARE_OP_LESS()}},15})
    V.Device.destroy_shader_module(device,vertex)
    V.Device.destroy_shader_module(device,fragment)
    return pipeline

def create(+device:V.Device,+pass:V.RenderPass,+front:U32,+cull:U32) -> V.Action(Pipelines):
  do V.Action<Pipelines>:
    +basic_layout:V.PipelineLayout <- V.Device.create_pipeline_layout(device,V.PipelineLayoutCreateInfo{[],Some{V.PushConstantRange{vk.VK_SHADER_STAGE_VERTEX_BIT(),64}}})
    basic:V.GraphicsPipeline <- pipeline(device,pass,basic_layout,front,cull,False{})
    +schema:V.DescriptorSetLayout <- T.schema(device)
    +textured_layout:V.PipelineLayout <- V.Device.create_pipeline_layout(device,V.PipelineLayoutCreateInfo{[schema],Some{V.PushConstantRange{U32.or(vk.VK_SHADER_STAGE_VERTEX_BIT(),vk.VK_SHADER_STAGE_FRAGMENT_BIT()),128}}})
    textured:V.GraphicsPipeline <- pipeline(device,pass,textured_layout,front,cull,True{})
    return Pipelines{basic,basic_layout,textured,textured_layout,schema}

def destroy(+device:V.Device,pipelines:Pipelines) -> V.Action(Unit):
  Pipelines{basic,basic_layout,textured,textured_layout,schema} = pipelines
  do V.Action<Unit>:
    V.Device.destroy_graphics_pipeline(device,basic)
    V.Device.destroy_graphics_pipeline(device,textured)
    V.Device.destroy_pipeline_layout(device,basic_layout)
    V.Device.destroy_pipeline_layout(device,textured_layout)
    V.Device.destroy_descriptor_set_layout(device,schema)

def basic(pipelines:Pipelines) -> V.GraphicsPipeline:
  Pipelines{basic,_,_,_,_} = pipelines
  basic

def textured(pipelines:Pipelines) -> V.GraphicsPipeline:
  Pipelines{_,_,textured,_,_} = pipelines
  textured
