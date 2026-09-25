#!/usr/bin/env python3
"""Translate OpenGOAL's desktop GLSL 4.10 shaders to GLSL ES 3.00 for the iOS GL renderer.

Desktop GLSL allows implicit int/float conversions and 1D textures; GLSL ES does not. Each shader is
parsed by glslang (desktop semantics), lowered to SPIR-V, and re-emitted by SPIRV-Cross as ES 3.00,
which makes every conversion explicit. 1D samplers become height-1 2D samplers first (the renderer
uploads them that way, see game/graphics/ottsel_gles_compat.h). Every result is validated as ES.

usage: translate-gl-shaders.py <shader-dir> <out-dir>
"""
import pathlib, re, subprocess, sys, tempfile

ROW = 1024  # OTTSEL_GLES_1D_ROW in game/graphics/ottsel_gles_compat.h
FOLD = f"ivec2 ottsel_fold1d(int i) {{ return ivec2(i % {ROW}, i / {ROW}); }}\n"
JAK1 = {"HEIGHT_SCALE": "1.0", "SCISSOR_HEIGHT": "448.0", "SCISSOR_ADJUST": "(512.0 / 448.0)"}


def wrap_first_arg(src, fn, name, open_, close):
    out, pos, head = [], 0, f"{fn}({name},"
    while (at := src.find(head, pos)) >= 0:
        out.append(src[pos:at] + head + " " + open_)
        i, depth = at + len(head), 0
        while i < len(src):
            c = src[i]
            if c == "(": depth += 1
            elif c == ")":
                if depth == 0: break
                depth -= 1
            elif c == "," and depth == 0: break
            out.append(c); i += 1
        out.append(close); pos = i
    return "".join(out) + src[pos:]


# Signed integer vertex inputs that the renderer feeds with unsigned data (glVertexAttribIPointer with
# GL_UNSIGNED_SHORT/BYTE/INT). Desktop GL converts; Metal (ANGLE) refuses the pipeline ("attribute of type
# int cannot be read using MTLAttributeFormatUShort"). Declare them unsigned and convert in the shader;
# the values are small indices, so the result is identical.
UNSIGNED_FED = {"time_of_day_index", "uv", "vi"}


def unsigned_inputs(src):
    def fix(m):
        layout, kind, name = m.group(1), m.group(2), m.group(3)
        if name not in UNSIGNED_FED:
            return m.group(0)
        utype = {"int": "uint", "ivec2": "uvec2", "ivec3": "uvec3", "ivec4": "uvec4"}[kind]
        return f"{layout}in {utype} ottsel_u_{name};\n#define {name} {kind}(ottsel_u_{name})"
    return re.sub(r"(layout\s*\(\s*location\s*=\s*\d+\s*\)\s*)in\s+(int|ivec[234])\s+(\w+)\s*;", fix, src)


def desktop_prepare(src):
    for key, value in JAK1.items():  # Shader.cpp substitutes these at load time on desktop
        src = src.replace(key, value)
    src = re.sub(r"\bnoperspective\s+", "", src)
    src = unsigned_inputs(src)
    one_d = re.findall(r"uniform\s+[iu]?sampler1D\s+(\w+)", src)
    src = re.sub(r"\b([iu]?)sampler1D\b", r"\1sampler2D", src)
    if one_d:  # palettes wider than ROW texels are folded into rows (ottsel_gles_tex_image_1d)
        head, _, rest = src.partition("\n")
        src = head + "\n" + FOLD + rest
    for name in one_d:
        src = wrap_first_arg(src, "texture", name, "vec2(", ", 0.5)")
        src = wrap_first_arg(src, "texelFetch", name, "ottsel_fold1d(", ")")
        src = re.sub(r"textureSize\(\s*%s\s*,\s*([^)]*)\)" % name, rf"textureSize({name}, \1).x", src)
    return src


def run(args):
    p = subprocess.run(args, capture_output=True, text=True)
    return p.returncode, (p.stdout + p.stderr).strip()


def main():
    src_dir, out_dir = map(pathlib.Path, sys.argv[1:3])
    out_dir.mkdir(parents=True, exist_ok=True)
    failures = []
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        for shader in sorted(src_dir.glob("*.vert")) + sorted(src_dir.glob("*.frag")):
            stage = shader.suffix[1:]
            prepared = tmp / shader.name
            prepared.write_text(desktop_prepare(shader.read_text()))
            spv = tmp / (shader.name + ".spv")
            code, log = run(["glslangValidator", "-G", "--aml", "--amb", "-S", stage, "-o", spv, prepared])
            if code:
                failures.append((shader.name, "glslang", log)); continue
            out = out_dir / shader.name
            code, log = run(["spirv-cross", spv, "--es", "--version", "300", "--output", out])
            if code:
                failures.append((shader.name, "spirv-cross", log)); continue
            # Desktop GL computes in full precision; keep it (SPIRV-Cross defaults fragments to mediump).
            out.write_text(out.read_text().replace("precision mediump float;", "precision highp float;"))
            code, log = run(["glslangValidator", "-S", stage, out])  # must be valid GLSL ES 3.00
            if code:
                failures.append((shader.name, "es-validate", log))
    for name, step, log in failures:
        print(f"FAIL {name} [{step}]\n{log}\n")
    print(f"translated {len(list(out_dir.iterdir()))} shaders, {len(failures)} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
