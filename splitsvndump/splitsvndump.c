#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/unistd.h>
#include <sys/uio.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <errno.h>
#include <fcntl.h>

int currev;
size_t curoff;
unsigned char* mapping;
size_t maplen;

#define MAX_INTVALUELEN 32

typedef struct {
    void* key_addr;
    void* value_addr;
    size_t key_len;
    size_t value_len;
} header_t;

static void
dumpline(const char* p){
    char buf[128];
    memcpy(buf, p, 128);
    buf[127] = 0;
    fprintf(stderr, "Dump: %s\n", buf);
}

static long
intvalue(const header_t* hdr){
    char buf[MAX_INTVALUELEN];
    if(hdr->value_len >= MAX_INTVALUELEN){
        fprintf(stderr, "Value too long, %ld\n",
                hdr->value_addr - (void*)mapping);
        exit(-1);
    }
    if(! hdr->value_len){
        fprintf(stderr, "No value, %ld\n",
                hdr->value_addr - (void*)mapping);
        exit(-1);
    }

    memcpy(buf, hdr->value_addr, hdr->value_len);
    buf[hdr->value_len] = 0;

    return atol(buf);
}

static int /* bool */
nullhdr_p(const header_t* hdr){
    if(hdr->key_len){
        return 0;
    }
    return 1;
}

static int /* 0, EOF */
read_header(header_t* hdr){
    unsigned char c;
    size_t linestart;
    size_t valuestart;
    if(curoff >= maplen){
        return EOF;
    }

    valuestart = 0;

    hdr->key_addr = hdr->value_addr = NULL;
    hdr->key_len = hdr->value_len = 0;
    linestart = curoff;
    while(1){
        c = mapping[curoff];
        switch(c){
            case ':':
                hdr->key_addr = &mapping[linestart];
                hdr->key_len = curoff - linestart;
                curoff++;
                curoff++; /* Consume a space */
                valuestart = curoff;
                break;
            case '\n':
                if(linestart == curoff){
                    /* Empty line, do nothing, return null header */
                }else if(valuestart){
                    hdr->value_addr = &mapping[valuestart];
                    hdr->value_len = curoff - valuestart;
                }else{
                    hdr->value_addr = &mapping[linestart];
                    hdr->value_len = curoff - linestart;
                }
                curoff++;
                return 0;
            default:
                curoff++;
                break;

        }
    }
}

static int /* bool */
is_header_p(const char* header_name, header_t* hdr){
    int r;
    if(! hdr->key_len){
        fprintf(stderr, "No key for [%s]\n", header_name);
        exit(-1);
    }
    r = strncmp(hdr->key_addr, header_name, hdr->key_len);
    if(!r){
        return 1;
    }
    return 0;
}

static int /* 0, EOF */
seek_to(const char* header_name, header_t* out_hdr){
    int r;
    while(1){
        dumpline(&mapping[curoff]);
        r = read_header(out_hdr);
        if(r == EOF){
            return EOF;
        }
        if(! out_hdr->key_len){
            if(out_hdr->value_len){
                fprintf(stderr, "Unexpected content line for [%s]\n",
                        header_name);
                exit(-1);
            }
            /* Ignore empty line */
            continue;
        }
        printf("Check for [%s]\n", header_name);
        r = strncmp(out_hdr->key_addr, header_name, out_hdr->key_len);
        if(!r){
            return 0;
        }
    }
}

static int
run(void){
    /* 
     * Content skipping = Collect node properties:
     *
     *  0. Skip repository header
     *  1. Collect revnumber and Skip for nodes
     *  2. Collect nodes
     *  3. Output a file for the revision
     *  4. Goto 1 until EOF
     *
     *  (Skip repository header)
     *  = Skip for `Revision-number`
     *
     *  (Collect revnumber and Skip for nodes)
     *  1. Current header should be `Revision-number`
     *  2. Skip for `Content-length`
     *  3. curoff += Content-length + 1(empty line)
     *
     *  (Collect nodes)
     *  1. Current header should be `Node-path`
     *  2. Calc Text/Prop length
     *     `Prop-content-length` for bytesize of Prop
     *     `Text-content-length` for content length
     *     (Text-content-length is optional, Prop-content-length will be 10
     *      if no properties existed which is for "PROPS-END\n")
     *  3. Seek to `Content-length`
     *  4. curoff += Content-length + 1(empty line) for the next header
     *  5. Check current header:
     *     `Revision-number` => Next revision
     *     `Node-path`       => Next node
     *     (EOF)             => term
     */

    int r;
    header_t hdr;
    long len,proplen;
    currev = -1;
    curoff = 0; /* off = 0 must point beginning of the header */

    /* #0 : Skip Repository header */
    r = seek_to("Revision-number", &hdr);
    if(r == EOF){
        fprintf(stderr, "Cannot find any revision\n");
        exit(-1);
    }
    while(1){
for_next_revision:
        /* #1 : Collect revnumber and Skip for nodes */
        currev = intvalue(&hdr);
        printf("Revision = %d (%ld)\n", currev, curoff);
        r = seek_to("Content-length", &hdr);
        if(r == EOF){
            fprintf(stderr, "Cannot get content-length (rev)\n");
            exit(-1);
        }
        len = intvalue(&hdr);
        curoff += (len + 2);
        /* #2 : Collect nodes */
        while(1){
next_node:
            dumpline(&mapping[curoff]);
            r = read_header(&hdr);
            if(r == EOF){
                break;
            }
            if(is_header_p("Revision-number", &hdr)){
                goto for_next_revision;
            }else{
                if(! is_header_p("Node-path", &hdr)){
                    fprintf(stderr, "Unexpected header (node)\n");
                    exit(-1);
                }
                while(1){
                    r = read_header(&hdr);
                    if(r == EOF){
                        fprintf(stderr, "Unexpected EOF(content-length)\n");
                        exit(-1);
                    }
                    if(nullhdr_p(&hdr)){
                        if(mapping[curoff] == '\n'){
                            printf("Null seek: %ld ", curoff);
                            curoff += 1;
                            printf("=> %ld\n", curoff);
                        }else{
                            printf("FIXME:\n");
                        }
                        goto next_node;
                    }else if(is_header_p("Prop-content-length", &hdr)){
                        proplen = intvalue(&hdr);
                        printf("  proplen = %ld\n", proplen);
                    }else if(is_header_p("Content-length", &hdr)){
                        len = intvalue(&hdr);
                        printf("seek: %ld ", curoff);
                        curoff += (len + 3);
                        printf("=> %ld\n", curoff);
                        break;
                    }
                }
            }
        }

        /* #3 : Output a file for the revision */
        /* #4 : Goto 1 until EOF */
    }

    if(curoff != maplen){
        fprintf(stderr, "WARNING: Read extra %ld bytes\n", curoff - maplen);
    }
    return 0;
}

int
main(int ac, char** av){
    int fd;
    int r;
    struct stat st;

    if(ac != 2){
        fprintf(stderr, "Usage: <EXEC> <FILENAME>\n");
        return -1;
    }

    /* Init */
    fd = open(av[1], O_RDONLY);
    if(fd < 0){
        fprintf(stderr, "File not found: %d\n", errno);
        return -1;
    }
    r = fstat(fd, &st);
    if(r < 0){
        fprintf(stderr, "huh? %d\n", errno);
        return -1;
    }
    maplen = st.st_size;

    printf("Map %d %ld\n", fd, maplen);
    mapping = mmap(NULL, maplen, PROT_READ, MAP_PRIVATE, fd, 0);
    if(mapping == MAP_FAILED){
        fprintf(stderr, "huh? (mmap) %d\n", errno);
        return -1;
    }

    return run();
}
