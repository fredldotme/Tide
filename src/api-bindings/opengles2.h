#ifndef OPENGLES2_API_BINDING_H
#define OPENGLES2_API_BINDING_H

#include <GLES2/gl2.h>
#include <wasm_export.h>
#include <lib_export.h>

#include <QDebug>

extern "C" {
void static wamr_binding_glActiveTexture (wasm_exec_env_t exec_env, GLenum texture) {
    glActiveTexture(texture);
}

void static wamr_binding_glAttachShader (wasm_exec_env_t exec_env, GLuint program, GLuint shader) {
    glAttachShader(program, shader);
}

void static wamr_binding_glBindAttribLocation (wasm_exec_env_t exec_env, GLuint program, GLuint index, const GLchar *name) {
    glBindAttribLocation(program, index, name);
}

void static wamr_binding_glBindBuffer (wasm_exec_env_t exec_env, GLenum target, GLuint buffer) {
    glBindBuffer(target, buffer);
}

void static wamr_binding_glBindFramebuffer (wasm_exec_env_t exec_env, GLenum target, GLuint framebuffer)
{
    glBindFramebuffer(target, framebuffer);
}

void static wamr_binding_glBindRenderbuffer (wasm_exec_env_t exec_env, GLenum target, GLuint renderbuffer)
{
    glBindRenderbuffer(target, renderbuffer);
}

void static wamr_binding_glBindTexture (wasm_exec_env_t exec_env, GLenum target, GLuint texture) {
    glBindTexture(target, texture);
}

void static wamr_binding_glBlendColor (wasm_exec_env_t exec_env, GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)
{
    glBlendColor(red, green, blue, alpha);
}

void static wamr_binding_glBlendEquation (wasm_exec_env_t exec_env, GLenum mode) {
    glBlendEquation(mode);
}

void static wamr_binding_glBlendEquationSeparate (wasm_exec_env_t exec_env, GLenum modeRGB, GLenum modeAlpha)
{
    glBlendEquationSeparate(modeRGB, modeAlpha);
}

void static wamr_binding_glBlendFunc (wasm_exec_env_t exec_env, GLenum sfactor, GLenum dfactor)
{
    glBlendFunc(sfactor, dfactor);
}

void static wamr_binding_glBlendFuncSeparate (wasm_exec_env_t exec_env, GLenum sfactorRGB, GLenum dfactorRGB, GLenum sfactorAlpha, GLenum dfactorAlpha)
{
    glBlendFuncSeparate(sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha);
}

void static wamr_binding_glBufferData (wasm_exec_env_t exec_env, GLenum target, GLsizeiptr size, const void *data, GLenum usage)
{
    glBufferData(target, size, data, usage);
}

void static wamr_binding_glBufferSubData (wasm_exec_env_t exec_env, GLenum target, GLintptr offset, GLsizeiptr size, const void *data)
{
    glBufferSubData(target, offset, size, data);
}

GLenum static wamr_binding_glCheckFramebufferStatus (wasm_exec_env_t exec_env, GLenum target)
{
    return glCheckFramebufferStatus(target);
}

void static wamr_binding_glClear (wasm_exec_env_t exec_env, GLbitfield mask)
{
    glClear(mask);
}

void static wamr_binding_glClearColor (wasm_exec_env_t exec_env, GLfloat red, GLfloat green, GLfloat blue, GLfloat alpha)
{
    glClearColor(red, green, blue, alpha);
}

void static wamr_binding_glClearDepthf (wasm_exec_env_t exec_env, GLfloat d)
{
    glClearDepthf(d);
}

void static wamr_binding_glClearStencil (wasm_exec_env_t exec_env, GLint s)
{
    glClearStencil(s);
}

void static wamr_binding_glColorMask (wasm_exec_env_t exec_env, GLboolean red, GLboolean green, GLboolean blue, GLboolean alpha)
{
    glColorMask(red, green, blue, alpha);
}

void static wamr_binding_glCompileShader (wasm_exec_env_t exec_env, GLuint shader) {
    glCompileShader(shader);
}

void static wamr_binding_glCompressedTexImage2D (wasm_exec_env_t exec_env, GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLsizei imageSize, const void *data)
{
    glCompressedTexImage2D(target, level, internalformat, width, height, border, imageSize, data);
}

void static wamr_binding_glCompressedTexSubImage2D (wasm_exec_env_t exec_env, GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLsizei imageSize, const void *data)
{
    glCompressedTexSubImage2D(target, level, xoffset, yoffset, width, height, format, imageSize, data);
}

void static wamr_binding_glCopyTexImage2D (wasm_exec_env_t exec_env, GLenum target, GLint level, GLenum internalformat, GLint x, GLint y, GLsizei width, GLsizei height, GLint border)
{
    glCopyTexImage2D(target, level, internalformat, x, y, width, height, border);
}

void static wamr_binding_glCopyTexSubImage2D (wasm_exec_env_t exec_env, GLenum target, GLint level, GLint xoffset, GLint yoffset, GLint x, GLint y, GLsizei width, GLsizei height)
{
    glCopyTexSubImage2D(target, level, xoffset, yoffset, x, y, width, height);
}

GLuint static wamr_binding_glCreateProgram (wasm_exec_env_t exec_env)
{
    return glCreateProgram();
}

GLuint static wamr_binding_glCreateShader (wasm_exec_env_t exec_env, GLenum type)
{
    return glCreateShader(type);
}

void static wamr_binding_glCullFace (wasm_exec_env_t exec_env, GLenum mode) {
    glCullFace(mode);
}

void static wamr_binding_glDeleteBuffers (wasm_exec_env_t exec_env, GLsizei n, const GLuint *buffers) {
    glDeleteBuffers(n, buffers);
}

void static wamr_binding_glDeleteFramebuffers (wasm_exec_env_t exec_env, GLsizei n, const GLuint *framebuffers) {
    glDeleteFramebuffers(n, framebuffers);
}
void static wamr_binding_glDeleteProgram (wasm_exec_env_t exec_env, GLuint program) {
    glDeleteProgram(program);
}

void static wamr_binding_glDeleteRenderbuffers (wasm_exec_env_t exec_env, GLsizei n, const GLuint *renderbuffers)
{
    glDeleteRenderbuffers(n, renderbuffers);
}

void static wamr_binding_glDeleteShader (wasm_exec_env_t exec_env, GLuint shader) {
    glDeleteShader(shader);
}

void static wamr_binding_glDeleteTextures (wasm_exec_env_t exec_env, GLsizei n, const GLuint *textures) {
    glDeleteTextures(n, textures);
}

void static wamr_binding_glDepthFunc (wasm_exec_env_t exec_env, GLenum func) {
    glDepthFunc(func);
}

void static wamr_binding_glDepthMask (wasm_exec_env_t exec_env, GLboolean flag) {
    glDepthMask(flag);
}

void static wamr_binding_glDepthRangef (wasm_exec_env_t exec_env, GLfloat n, GLfloat f) {
    glDepthRangef(n, f);
}

void static wamr_binding_glDetachShader (wasm_exec_env_t exec_env, GLuint program, GLuint shader) {
    glDetachShader(program, shader);
}

void static wamr_binding_glDisable (wasm_exec_env_t exec_env, GLenum cap)
{
    glDisable(cap);
}

void static wamr_binding_glDisableVertexAttribArray (wasm_exec_env_t exec_env, GLuint index) {
    glDisableVertexAttribArray(index);
}

void static wamr_binding_glDrawArrays (wasm_exec_env_t exec_env, GLenum mode, GLint first, GLsizei count)
{
    glDrawArrays(mode, first, count);
}

void static wamr_binding_glDrawElements (wasm_exec_env_t exec_env, GLenum mode, GLsizei count, GLenum type, const void *indices)
{
    glDrawElements(mode, count, type, indices);
}

void static wamr_binding_glEnable (wasm_exec_env_t exec_env, GLenum cap) {
    glEnable(cap);
}

void static wamr_binding_glEnableVertexAttribArray (wasm_exec_env_t exec_env, GLuint index) {
    glEnableVertexAttribArray(index);
}

void static wamr_binding_glFinish (wasm_exec_env_t exec_env) {
    glFinish();
}

void static wamr_binding_glFlush (wasm_exec_env_t exec_env) {
    glFlush();
}

void static wamr_binding_glFramebufferRenderbuffer (wasm_exec_env_t exec_env, GLenum target, GLenum attachment, GLenum renderbuffertarget, GLuint renderbuffer) {
    glFramebufferRenderbuffer(target, attachment, renderbuffertarget, renderbuffer);
}

void static wamr_binding_glFramebufferTexture2D (wasm_exec_env_t exec_env, GLenum target, GLenum attachment, GLenum textarget, GLuint texture, GLint level)
{
    glFramebufferTexture2D(target, attachment, textarget, texture, level);
}

void static wamr_binding_glFrontFace (wasm_exec_env_t exec_env, GLenum mode) {
    glFrontFace(mode);
}

void static wamr_binding_glGenBuffers (wasm_exec_env_t exec_env, GLsizei n, GLuint *buffers) {
    glGenBuffers(n, buffers);
}

void static wamr_binding_glGenerateMipmap (wasm_exec_env_t exec_env, GLenum target) {
    glGenerateMipmap(target);
}

void static wamr_binding_glGenFramebuffers (wasm_exec_env_t exec_env, GLsizei n, GLuint *framebuffers) {
    glGenFramebuffers(n, framebuffers);
}

void static wamr_binding_glGenRenderbuffers (wasm_exec_env_t exec_env, GLsizei n, GLuint *renderbuffers)
{
    glGenRenderbuffers(n, renderbuffers);
}

void static wamr_binding_glGenTextures (wasm_exec_env_t exec_env, GLsizei n, GLuint *textures) {
    glGenTextures(n, textures);
}

void static wamr_binding_glGetActiveAttrib (wasm_exec_env_t exec_env, GLuint program, GLuint index, GLsizei bufSize, GLsizei *length, GLint *size, GLenum *type, GLchar *name) {}
void static wamr_binding_glGetActiveUniform (wasm_exec_env_t exec_env, GLuint program, GLuint index, GLsizei bufSize, GLsizei *length, GLint *size, GLenum *type, GLchar *name) {}
void static wamr_binding_glGetAttachedShaders (wasm_exec_env_t exec_env, GLuint program, GLsizei maxCount, GLsizei *count, GLuint *shaders) {}
GLint wamr_binding_glGetAttribLocation (wasm_exec_env_t exec_env, GLuint program, const GLchar *name) {}
void static wamr_binding_glGetBooleanv (wasm_exec_env_t exec_env, GLenum pname, GLboolean *data) {}
void static wamr_binding_glGetBufferParameteriv (wasm_exec_env_t exec_env, GLenum target, GLenum pname, GLint *params) {}
GLenum wamr_binding_glGetError (wasm_exec_env_t exec_env) {}
void static wamr_binding_glGetFloatv (wasm_exec_env_t exec_env, GLenum pname, GLfloat *data) {}
void static wamr_binding_glGetFramebufferAttachmentParameteriv (wasm_exec_env_t exec_env, GLenum target, GLenum attachment, GLenum pname, GLint *params) {}
void static wamr_binding_glGetIntegerv (wasm_exec_env_t exec_env, GLenum pname, GLint *data) {}
void static wamr_binding_glGetProgramiv (wasm_exec_env_t exec_env, GLuint program, GLenum pname, GLint *params) {}
void static wamr_binding_glGetProgramInfoLog (wasm_exec_env_t exec_env, GLuint program, GLsizei bufSize, GLsizei *length, GLchar *infoLog) {}
void static wamr_binding_glGetRenderbufferParameteriv (wasm_exec_env_t exec_env, GLenum target, GLenum pname, GLint *params) {}
void static wamr_binding_glGetShaderiv (wasm_exec_env_t exec_env, GLuint shader, GLenum pname, GLint *params) {}
void static wamr_binding_glGetShaderInfoLog (wasm_exec_env_t exec_env, GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *infoLog) {}
void static wamr_binding_glGetShaderPrecisionFormat (wasm_exec_env_t exec_env, GLenum shadertype, GLenum precisiontype, GLint *range, GLint *precision) {}
void static wamr_binding_glGetShaderSource (wasm_exec_env_t exec_env, GLuint shader, GLsizei bufSize, GLsizei *length, GLchar *source) {}
const GLubyte static *wamr_binding_glGetString (wasm_exec_env_t exec_env, GLenum name) {}
void static wamr_binding_glGetTexParameterfv (wasm_exec_env_t exec_env, GLenum target, GLenum pname, GLfloat *params) {}
void static wamr_binding_glGetTexParameteriv (wasm_exec_env_t exec_env, GLenum target, GLenum pname, GLint *params) {}
void static wamr_binding_glGetUniformfv (wasm_exec_env_t exec_env, GLuint program, GLint location, GLfloat *params) {}
void static wamr_binding_glGetUniformiv (wasm_exec_env_t exec_env, GLuint program, GLint location, GLint *params) {}
GLint static wamr_binding_glGetUniformLocation (wasm_exec_env_t exec_env, GLuint program, const GLchar *name) {}
void static wamr_binding_glGetVertexAttribfv (wasm_exec_env_t exec_env, GLuint index, GLenum pname, GLfloat *params) {}
void static wamr_binding_glGetVertexAttribiv (wasm_exec_env_t exec_env, GLuint index, GLenum pname, GLint *params) {}
void static wamr_binding_glGetVertexAttribPointerv (wasm_exec_env_t exec_env, GLuint index, GLenum pname, void **pointer) {}
void static wamr_binding_glHint (wasm_exec_env_t exec_env, GLenum target, GLenum mode) {}
GLboolean static wamr_binding_glIsBuffer (wasm_exec_env_t exec_env, GLuint buffer) {}
GLboolean static wamr_binding_glIsEnabled (wasm_exec_env_t exec_env, GLenum cap) {}
GLboolean static wamr_binding_glIsFramebuffer (wasm_exec_env_t exec_env, GLuint framebuffer) {}
GLboolean static wamr_binding_glIsProgram (wasm_exec_env_t exec_env, GLuint program) {}
GLboolean static wamr_binding_glIsRenderbuffer (wasm_exec_env_t exec_env, GLuint renderbuffer) {}
GLboolean static wamr_binding_glIsShader (wasm_exec_env_t exec_env, GLuint shader) {}
GLboolean static wamr_binding_glIsTexture (wasm_exec_env_t exec_env, GLuint texture) {}
void static wamr_binding_glLineWidth (wasm_exec_env_t exec_env, GLfloat width) {}
void static wamr_binding_glLinkProgram (wasm_exec_env_t exec_env, GLuint program) {}
void static wamr_binding_glPixelStorei (wasm_exec_env_t exec_env, GLenum pname, GLint param) {}
void static wamr_binding_glPolygonOffset (wasm_exec_env_t exec_env, GLfloat factor, GLfloat units) {}
void static wamr_binding_glReadPixels (wasm_exec_env_t exec_env, GLint x, GLint y, GLsizei width, GLsizei height, GLenum format, GLenum type, void *pixels) {}
void static wamr_binding_glReleaseShaderCompiler (wasm_exec_env_t exec_env) {
    glReleaseShaderCompiler();
}

void static wamr_binding_glRenderbufferStorage (wasm_exec_env_t exec_env, GLenum target, GLenum internalformat, GLsizei width, GLsizei height) {}
void static wamr_binding_glSampleCoverage (wasm_exec_env_t exec_env, GLfloat value, GLboolean invert) {}
void static wamr_binding_glScissor (wasm_exec_env_t exec_env, GLint x, GLint y, GLsizei width, GLsizei height) {}
void static wamr_binding_glShaderBinary (wasm_exec_env_t exec_env, GLsizei count, const GLuint *shaders, GLenum binaryformat, const void *binary, GLsizei length) {}
void static wamr_binding_glShaderSource (wasm_exec_env_t exec_env, GLuint shader, GLsizei count, const GLchar *const*string, const GLint *length) {}
void static wamr_binding_glStencilFunc (wasm_exec_env_t exec_env, GLenum func, GLint ref, GLuint mask) {}
void static wamr_binding_glStencilFuncSeparate (wasm_exec_env_t exec_env, GLenum face, GLenum func, GLint ref, GLuint mask) {}
void static wamr_binding_glStencilMask (wasm_exec_env_t exec_env, GLuint mask) {}
void static wamr_binding_glStencilMaskSeparate (wasm_exec_env_t exec_env, GLenum face, GLuint mask) {}
void static wamr_binding_glStencilOp (wasm_exec_env_t exec_env, GLenum fail, GLenum zfail, GLenum zpass) {}
void static wamr_binding_glStencilOpSeparate (wasm_exec_env_t exec_env, GLenum face, GLenum sfail, GLenum dpfail, GLenum dppass) {}
void static wamr_binding_glTexImage2D (wasm_exec_env_t exec_env, GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const void *pixels) {
    glTexImage2D(target, level, internalformat, width, height, border, format, type, pixels);
}

void static wamr_binding_glTexParameterf (wasm_exec_env_t exec_env, GLenum target, GLenum pname, GLfloat param) {}
void static wamr_binding_glTexParameterfv (wasm_exec_env_t exec_env, GLenum target, GLenum pname, const GLfloat *params) {}

void static wamr_binding_glTexParameteri (wasm_exec_env_t exec_env, GLenum target, GLenum pname, GLint param) {
    glTexParameteri(target, pname, param);
}

void static wamr_binding_glTexParameteriv (wasm_exec_env_t exec_env, GLenum target, GLenum pname, const GLint *params) {}
void static wamr_binding_glTexSubImage2D (wasm_exec_env_t exec_env, GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const void *pixels) {}
void static wamr_binding_glUniform1f (wasm_exec_env_t exec_env, GLint location, GLfloat v0) {}
void static wamr_binding_glUniform1fv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLfloat *value) {}
void static wamr_binding_glUniform1i (wasm_exec_env_t exec_env, GLint location, GLint v0) {}
void static wamr_binding_glUniform1iv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLint *value) {}
void static wamr_binding_glUniform2f (wasm_exec_env_t exec_env, GLint location, GLfloat v0, GLfloat v1) {}
void static wamr_binding_glUniform2fv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLfloat *value) {}
void static wamr_binding_glUniform2i (wasm_exec_env_t exec_env, GLint location, GLint v0, GLint v1) {}
void static wamr_binding_glUniform2iv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLint *value) {}
void static wamr_binding_glUniform3f (wasm_exec_env_t exec_env, GLint location, GLfloat v0, GLfloat v1, GLfloat v2) {}
void static wamr_binding_glUniform3fv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLfloat *value) {}
void static wamr_binding_glUniform3i (wasm_exec_env_t exec_env, GLint location, GLint v0, GLint v1, GLint v2) {}
void static wamr_binding_glUniform3iv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLint *value) {}
void static wamr_binding_glUniform4f (wasm_exec_env_t exec_env, GLint location, GLfloat v0, GLfloat v1, GLfloat v2, GLfloat v3) {}
void static wamr_binding_glUniform4fv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLfloat *value) {}
void static wamr_binding_glUniform4i (wasm_exec_env_t exec_env, GLint location, GLint v0, GLint v1, GLint v2, GLint v3) {}
void static wamr_binding_glUniform4iv (wasm_exec_env_t exec_env, GLint location, GLsizei count, const GLint *value) {}
void static wamr_binding_glUniformMatrix2fv (wasm_exec_env_t exec_env, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value) {}
void static wamr_binding_glUniformMatrix3fv (wasm_exec_env_t exec_env, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value) {}
void static wamr_binding_glUniformMatrix4fv (wasm_exec_env_t exec_env, GLint location, GLsizei count, GLboolean transpose, const GLfloat *value) {}
void static wamr_binding_glUseProgram (wasm_exec_env_t exec_env, GLuint program) {}
void static wamr_binding_glValidateProgram (wasm_exec_env_t exec_env, GLuint program) {}
void static wamr_binding_glVertexAttrib1f (wasm_exec_env_t exec_env, GLuint index, GLfloat x) {}
void static wamr_binding_glVertexAttrib1fv (wasm_exec_env_t exec_env, GLuint index, const GLfloat *v) {}
void static wamr_binding_glVertexAttrib2f (wasm_exec_env_t exec_env, GLuint index, GLfloat x, GLfloat y) {}
void static wamr_binding_glVertexAttrib2fv (wasm_exec_env_t exec_env, GLuint index, const GLfloat *v) {}
void static wamr_binding_glVertexAttrib3f (wasm_exec_env_t exec_env, GLuint index, GLfloat x, GLfloat y, GLfloat z) {}
void static wamr_binding_glVertexAttrib3fv (wasm_exec_env_t exec_env, GLuint index, const GLfloat *v) {}
void static wamr_binding_glVertexAttrib4f (wasm_exec_env_t exec_env, GLuint index, GLfloat x, GLfloat y, GLfloat z, GLfloat w) {}
void static wamr_binding_glVertexAttrib4fv (wasm_exec_env_t exec_env, GLuint index, const GLfloat *v) {}

void static wamr_binding_glVertexAttribPointer (wasm_exec_env_t exec_env, GLuint index, GLint size, GLenum type, GLboolean normalized, GLsizei stride, const void *pointer)
{
    glVertexAttribPointer(index, size, type, normalized, stride, pointer);
}

void static wamr_binding_glViewport (wasm_exec_env_t exec_env, GLint x, GLint y, GLsizei width, GLsizei height) {
    glViewport(x, y, width, height);
}

#define ADD_SYMBOL(name, signature) \
{ #name, (void*) wamr_binding_##name, signature, nullptr }

static NativeSymbol gles2_native_symbols[] = {
    ADD_SYMBOL(glActiveTexture, "(i)"),
    ADD_SYMBOL(glAttachShader, "(ii)"),
    ADD_SYMBOL(glBindAttribLocation, "(ii$)"),
    ADD_SYMBOL(glBindBuffer, "(ii)"),
    ADD_SYMBOL(glBindFramebuffer, "(ii)"),
    ADD_SYMBOL(glBindRenderbuffer, "(ii)"),
    ADD_SYMBOL(glBindTexture, "(ii)"),
    ADD_SYMBOL(glBlendColor, "(ffff)"),
    ADD_SYMBOL(glBlendEquation, "(i)"),
    ADD_SYMBOL(glBlendEquationSeparate, "(ii)"),
    ADD_SYMBOL(glBlendFunc, "(ii)"),
    ADD_SYMBOL(glBlendFuncSeparate, "(ii)"),
    ADD_SYMBOL(glBufferData, "(iI*i)"),
    ADD_SYMBOL(glBufferSubData, "(iII*)"),
    ADD_SYMBOL(glCheckFramebufferStatus, "(i)i"),
    ADD_SYMBOL(glClear, "(i)"),
    ADD_SYMBOL(glClearColor, "(ffff)"),
    ADD_SYMBOL(glClearDepthf, "(f)"),
    ADD_SYMBOL(glClearStencil, "(i)"),
    ADD_SYMBOL(glColorMask, "(iiii)"),
    ADD_SYMBOL(glCompileShader, "(i)"),
    ADD_SYMBOL(glCompressedTexImage2D, "(iiiiiii*)"),
    ADD_SYMBOL(glCompressedTexSubImage2D, "(iiiiiiii*)"),
    ADD_SYMBOL(glCopyTexImage2D, "(iiiiiiii)"),
    ADD_SYMBOL(glCopyTexSubImage2D, "(iiiiiiii)"),
    ADD_SYMBOL(glCreateProgram, "()i"),
    ADD_SYMBOL(glCreateShader, "(i)i"),
    ADD_SYMBOL(glCullFace, "(i)"),
    ADD_SYMBOL(glDeleteBuffers, "(i*"),
    ADD_SYMBOL(glDeleteFramebuffers, "(i*)"),
    ADD_SYMBOL(glDeleteProgram, "(i)"),
    ADD_SYMBOL(glDeleteRenderbuffers, "(i*)"),
    ADD_SYMBOL(glDeleteShader, "(i)"),
    ADD_SYMBOL(glDeleteTextures, "(i*)"),
    ADD_SYMBOL(glDepthFunc, "(i)"),
    ADD_SYMBOL(glDepthMask, "(i)"),
    ADD_SYMBOL(glDepthRangef, "(ff)"),
    ADD_SYMBOL(glDetachShader, "(ii)"),
    ADD_SYMBOL(glDisable, "(i)"),
    ADD_SYMBOL(glDisableVertexAttribArray, "(i)"),
    ADD_SYMBOL(glDrawArrays, "(iii)"),
    ADD_SYMBOL(glDrawElements, "(iii*)"),
    ADD_SYMBOL(glEnable, "(i)"),
    ADD_SYMBOL(glEnableVertexAttribArray, "(i)"),
    ADD_SYMBOL(glFinish, "()"),
    ADD_SYMBOL(glFlush, "()"),
    ADD_SYMBOL(glFramebufferRenderbuffer, "(iiii)"),
    ADD_SYMBOL(glFramebufferTexture2D, "(iiiii)"),
    ADD_SYMBOL(glFrontFace, "(i)"),
    ADD_SYMBOL(glGenBuffers, "(i*)"),
    ADD_SYMBOL(glGenerateMipmap, "(i)"),
    ADD_SYMBOL(glGenFramebuffers, "(i*)"),
    ADD_SYMBOL(glGenRenderbuffers, "(i*)"),
    ADD_SYMBOL(glGenTextures, "(i*)")
};

void register_wamr_opengles_bindings() {
    const int n_native_symbols = sizeof(gles2_native_symbols) / sizeof(NativeSymbol);
    if (!wasm_runtime_register_natives("env", gles2_native_symbols, n_native_symbols)) {
        qWarning() << "Failed to register OpenGL ES2 APIs";
    } else {
        qInfo() << "Successfully registered OpenGL ES2 APIs";
    }
}
} // extern "C"

#endif // OPENGLES2_API_BINDING_H
