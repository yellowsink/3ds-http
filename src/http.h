#ifndef INC_3DS_HTTP_HTTP_H
#define INC_3DS_HTTP_HTTP_H

#define TLS1_1_ERROR 0xd8a0a03c

Result http_start_req(httpcContext* ctx, const char* url, u32* res_code);

Result http_download(const char* url, FILE* f, u32* sizeo);

#endif //INC_3DS_HTTP_HTTP_H
