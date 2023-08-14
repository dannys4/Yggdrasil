using BinaryBuilder, Pkg

const YGGDRASIL_DIR = "../../.."
include(joinpath(YGGDRASIL_DIR, "fancy_toys.jl"))
include(joinpath(YGGDRASIL_DIR, "platforms", "cuda.jl"))

name = "CUDA_Runtime"
version = v"0.7.0"

augment_platform_block = """
    $(read(joinpath(@__DIR__, "platform_augmentation.jl"), String))
    const cuda_toolkits = $(CUDA.cuda_full_versions)"""

# determine exactly which tarballs we should build
builds = []
for cuda_version in CUDA.cuda_full_versions
    cuda_tag = "$(cuda_version.major).$(cuda_version.minor)"
    dependencies = [BuildDependency(PackageSpec(name="CUDA_full_jll",
                                                version=cuda_version))]
    include("build_$(cuda_tag).jl")

    for platform in platforms
        augmented_platform = deepcopy(platform)
        augmented_platform["cuda"] = CUDA.platform(cuda_version)

        should_build_platform(triplet(augmented_platform)) || continue
        push!(builds,
              (; dependencies=[Dependency("CUDA_Driver_jll"; compat="0.5"); dependencies],
                 script, products=get_products(platform), platforms=[augmented_platform],
        ))
    end
end

# don't allow `build_tarballs` to override platform selection based on ARGS.
# we handle that ourselves by calling `should_build_platform`
non_platform_ARGS = filter(arg -> startswith(arg, "--"), ARGS)

# `--register` should only be passed to the latest `build_tarballs` invocation
non_reg_ARGS = filter(arg -> arg != "--register", non_platform_ARGS)

for (i,build) in enumerate(builds)
    build_tarballs(i == lastindex(builds) ? non_platform_ARGS : non_reg_ARGS,
                   name, version, [], build.script,
                   build.platforms, build.products, build.dependencies;
                   julia_compat="1.6", preferred_gcc_version = v"6.1.0",
                   lazy_artifacts=true, augment_platform_block)
end
