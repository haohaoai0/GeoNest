#include "geonest_gis_core.h"

#include <cstring>
#include <cstdlib>
#include <cmath>
#include <map>
#include <vector>
#include <string>
#include <mutex>
#include <fstream>

namespace geonest {

struct PreparedProcessingTask {};

struct Vec2 { double x; double y; };
struct Ring { std::vector<Vec2> pts; };
struct Geom { int32_t type; std::vector<Ring> rings; std::vector<Vec2> pts; };
struct Field { std::string name; std::string typeName; std::string value; };
struct Feat { int64_t fid; Geom geom; std::vector<Field> fields; };
struct Layer {
    LayerHandle handle; std::string filePath; std::string name;
    int32_t geomType; std::string crs;
    double minX, minY, maxX, maxY;
    std::vector<std::string> fieldNames; std::vector<std::string> fieldTypes;
    std::vector<Feat> features;
    bool editSessionActive = false;
};

static std::mutex g_mutex;
static std::map<LayerHandle, Layer> g_layers;
static LayerHandle g_nextHandle = 1;

static char *Dup(const std::string &s) {
    char *b = static_cast<char*>(malloc(s.size()+1));
    if(b) memcpy(b, s.c_str(), s.size()+1);
    return b;
}

static std::string Esc(const std::string &s) {
    std::string o;
    for(size_t i=0;i<s.size();i++) {
        char c=s[i];
        if(c==0x22) { o+=0x5C; o+=0x22; }
        else if(c==0x5C) { o+=0x5C; o+=0x5C; }
        else if(c==0x0A) { o+=0x5C; o+=0x6E; }
        else if(c==0x0D) { o+=0x5C; o+=0x72; }
        else if(c==0x09) { o+=0x5C; o+=0x74; }
        else o+=c;
    }
    return o;
}

static int32_t ri32LE(const unsigned char *p) { return (int32_t)(p[0]|(p[1]<<8)|(p[2]<<16)|(p[3]<<24)); }
static int32_t ri32BE(const unsigned char *p) { return (int32_t)((p[0]<<24)|(p[1]<<16)|(p[2]<<8)|p[3]); }
static double rf64LE(const unsigned char *p) { double v; memcpy(&v,p,8); return v; }
static int16_t ri16LE(const unsigned char *p) { return (int16_t)(p[0]|(p[1]<<8)); }

static bool ReadShapefile(const std::string &path, Layer &layer) {
    std::string base = path;
    if(base.size()>4 && base.substr(base.size()-4)==".shp") base = base.substr(0, base.size()-4);
    std::string shpPath = base + ".shp";
    std::ifstream in(shpPath, std::ios::binary|std::ios::ate);
    if(!in.is_open()) return false;
    auto sz = in.tellg(); in.seekg(0);
    std::vector<unsigned char> d(sz);
    in.read(reinterpret_cast<char*>(d.data()), sz); in.close();
    if(sz < 100) return false;
    if(ri32BE(d.data())!=9994 || ri32LE(d.data()+32)!=1000) return false;
    layer.geomType = ri32LE(d.data()+36);
    layer.minX = rf64LE(d.data()+40);
    layer.minY = rf64LE(d.data()+48);
    layer.maxX = rf64LE(d.data()+56);
    layer.maxY = rf64LE(d.data()+64);
    // Normalize SHP geomType to internal constants
    // SHP spec: 1=Point, 3=PolyLine, 5=Polygon, 8=MultiPoint
    // Internal: 1=GEOM_POINT, 2=GEOM_LINESTRING, 3=GEOM_POLYGON
    int32_t shpGeomType = layer.geomType;
    if (shpGeomType == 3 || shpGeomType == 13 || shpGeomType == 23) layer.geomType = GEOM_LINESTRING;  // PolyLine
    else if (shpGeomType == 5 || shpGeomType == 15 || shpGeomType == 25) layer.geomType = GEOM_POLYGON; // Polygon
    else if (shpGeomType == 6 || shpGeomType == 16 || shpGeomType == 26) layer.geomType = GEOM_POLYGON; // MultiPolygon -> Polygon
    else if (shpGeomType == 8 || shpGeomType == 18 || shpGeomType == 28) layer.geomType = GEOM_POINT;   // MultiPoint
    int32_t off=100; int64_t fid=1;
    while(off+8<=(int32_t)sz) {
        int32_t cLen = ri32BE(d.data()+off+4)*2;
        if(cLen<=0||off+8+cLen>(int32_t)sz) break;
        const unsigned char *r = d.data()+off+8;
        int32_t rType = ri32LE(r);
        Feat f; f.fid = fid++;
        if(rType==1 && layer.geomType==GEOM_POINT) {
            f.geom.type = GEOM_POINT;
            f.geom.pts.push_back({rf64LE(r+4), rf64LE(r+12)});
        } else if((rType==3||rType==5||rType==6||rType==13||rType==15||rType==23||rType==25||rType==26) && (layer.geomType==GEOM_LINESTRING||layer.geomType==GEOM_POLYGON)) {
            f.geom.type = layer.geomType;
            int32_t nP = ri32LE(r+36), nPts = ri32LE(r+40);
            const unsigned char *pa = r+44, *pta = pa + nP*4;
            for(int32_t pi=0;pi<nP;pi++) {
                int32_t s0 = ri32LE(pa+pi*4);
                int32_t s1 = (pi+1<nP) ? ri32LE(pa+(pi+1)*4) : nPts;
                Ring ring;
                for(int32_t j=s0;j<s1;j++) ring.pts.push_back({rf64LE(pta+j*16), rf64LE(pta+j*16+8)});
                f.geom.rings.push_back(ring);
                if(layer.geomType!=GEOM_POLYGON) for(auto& pt:ring.pts) f.geom.pts.push_back(pt);
            }
        } else { off+=8+cLen; continue; }
        layer.features.push_back(f);
        off+=8+cLen;
    }
    std::string dbfPath = base + ".dbf";
    std::ifstream din(dbfPath, std::ios::binary|std::ios::ate);
    if(din.is_open()) {
        auto dsz = din.tellg(); din.seekg(0);
        std::vector<unsigned char> dd(dsz);
        din.read(reinterpret_cast<char*>(dd.data()), dsz); din.close();
        if(dsz>=32) {
            int32_t nRec = ri32LE(dd.data()+4);
            int16_t hdrL = ri16LE(dd.data()+8), recL = ri16LE(dd.data()+10);
            struct DF{std::string n;char t;int s;};
            std::vector<DF> flds;
            int fo=32;
            while(fo<hdrL-1&&fo+32<=(int)dsz) {
                DF df; df.n=""; for(int i=0;i<11;i++){char c=(char)dd[fo+i];if(c==0)break;df.n+=c;}
                df.t=(char)dd[fo+11]; df.s=dd[fo+16]; flds.push_back(df); fo+=32;
            }
            for(auto& f:flds) {
                layer.fieldNames.push_back(f.n);
                layer.fieldTypes.push_back(f.t==0x4E||f.t==0x46 ? "double" : "string");
            }
            for(int32_t ri=0;ri<nRec&&ri<(int)layer.features.size();ri++) {
                int32_t rs=hdrL+ri*recL; if(rs+recL>(int)dsz) break;
                int vo=rs+1;
                for(auto& f:flds) {
                    Field mf; mf.name=f.n;
                    mf.typeName=(f.t==0x4E||f.t==0x46)?"double":"string";
                    std::string rv;
                    for(int j=0;j<f.s&&vo+j<(int)dsz;j++){unsigned char c=dd[vo+j];if(c==0)break;rv+=(char)c;}
                    size_t p0=rv.find_first_not_of(0x20), p1=rv.find_last_not_of(0x20);
                    mf.value = p0!=std::string::npos ? rv.substr(p0,p1-p0+1) : "";
                    layer.features[ri].fields.push_back(mf);
                    vo+=f.s;
                }
            }
        }
    }
    std::string fn=base;
    size_t sl=fn.find_last_of("/\\");
    if(sl!=std::string::npos) fn=fn.substr(sl+1);
    layer.name=fn;
    layer.crs="EPSG:4326";
    return true;
}

static std::string BuildLayerJson(const Layer &L) {
    std::string j="{\"layerId\":\"L"+std::to_string(L.handle)+"\"";
    j+=",\"name\":\""+Esc(L.name)+"\"";
    j+=",\"geometryType\":"+std::to_string(L.geomType);
    j+=",\"hasZ\":false,\"hasM\":false";
    j+=",\"featureCount\":"+std::to_string((int)L.features.size());
    j+=",\"envelope\":{\"minX\":"+std::to_string(L.minX);
    j+=",\"minY\":"+std::to_string(L.minY);
    j+=",\"maxX\":"+std::to_string(L.maxX);
    j+=",\"maxY\":"+std::to_string(L.maxY)+"}";
    j+=",\"crs\":\""+Esc(L.crs)+"\"";
    j+=",\"fields\":[";
    for(size_t i=0;i<L.fieldNames.size();i++){
        if(i)j+=",";
        j+="{\"name\":\""+Esc(L.fieldNames[i])+"\"";
        j+=",\"alias\":\"\",\"typeName\":\""+Esc(L.fieldTypes[i])+"\"";
        j+=",\"width\":254,\"precision\":0,\"nullable\":true}";
    }
    j+="]}"; return j;
}

static std::string BuildGeomJson(const Geom &g) {
    std::string j="{\"geometryType\":"+std::to_string(g.type);
    j+=",\"parts\":[";
    if(g.type==GEOM_POLYGON) {
        for(size_t r=0;r<g.rings.size();r++){
            if(r)j+=",";
            j+="{\"points\":[";
            for(size_t p=0;p<g.rings[r].pts.size();p++){
                if(p)j+=",";
                auto& pt=g.rings[r].pts[p];
                j+="{\"x\":"+std::to_string(pt.x)+",\"y\":"+std::to_string(pt.y)+",\"z\":0,\"hasZ\":false}";
            }
            j+="]}";
        }
    } else {
        j+="{\"points\":[";
        for(size_t p=0;p<g.pts.size();p++){
            if(p)j+=",";
            auto& pt=g.pts[p];
            j+="{\"x\":"+std::to_string(pt.x)+",\"y\":"+std::to_string(pt.y)+",\"z\":0,\"hasZ\":false}";
        }
        j+="]}";
    }
    j+="]";
    double mnx=1e18,mny=1e18,mxx=-1e18,mxy=-1e18;
    auto upd=[&](double x,double y){if(x<mnx)mnx=x;if(y<mny)mny=y;if(x>mxx)mxx=x;if(y>mxy)mxy=y;};
    if(g.type==GEOM_POLYGON)for(auto&r:g.rings)for(auto&pt:r.pts)upd(pt.x,pt.y);
    else for(auto&pt:g.pts)upd(pt.x,pt.y);
    j+=",\"envelope\":{\"minX\":"+std::to_string(mnx)+",\"minY\":"+std::to_string(mny);
    j+=",\"maxX\":"+std::to_string(mxx)+",\"maxY\":"+std::to_string(mxy)+"}";
    j+=",\"crs\":\"\"}";
    return j;
}

static std::string BuildFeatJson(const Feat &f) {
    std::string j="{\"featureId\":\""+std::to_string(f.fid)+"\"";
    j+=",\"geometry\":"+BuildGeomJson(f.geom);
    double mnx=1e18,mny=1e18,mxx=-1e18,mxy=-1e18;
    auto upd=[&](double x,double y){if(x<mnx)mnx=x;if(y<mny)mny=y;if(x>mxx)mxx=x;if(y>mxy)mxy=y;};
    if(f.geom.type==GEOM_POLYGON)for(auto&r:f.geom.rings)for(auto&pt:r.pts)upd(pt.x,pt.y);
    else for(auto&pt:f.geom.pts)upd(pt.x,pt.y);
    j+=",\"envelope\":{\"minX\":"+std::to_string(mnx)+",\"minY\":"+std::to_string(mny);
    j+=",\"maxX\":"+std::to_string(mxx)+",\"maxY\":"+std::to_string(mxy)+"}";
    j+=",\"attributesPreview\":[";
    for(size_t i=0;i<f.fields.size();i++){
        if(i)j+=",";
        auto& fi=f.fields[i];
        j+="{\"name\":\""+Esc(fi.name)+"\",\"typeName\":\""+Esc(fi.typeName)+"\",\"textValue\":\""+Esc(fi.value)+"\"";
        j+=",\"numberValue\":0,\"boolValue\":false,\"isNull\":false}";
    }
    j+="]}"; return j;
}

const char *GetNativeVersion() { return "GeoNest GIS Native Core 0.3.0"; }
const char *GetCoreProfile() { return "SHP/DBF reader + mock fallback"; }

LayerHandle OpenVectorLayer(const char *filePath, char **outLayerInfo, int32_t *outErrCode) {
    if(!filePath){if(outErrCode)*outErrCode=GIS_ERR_INVALID_PARAM;return 0;}
    std::lock_guard<std::mutex> lk(g_mutex);
    Layer layer;
    layer.handle = g_nextHandle++;
    layer.filePath = filePath;
    std::string path(filePath);
    bool readOk = false;
    if(path.find(".shp")!=std::string::npos || path.find(".SHP")!=std::string::npos) {
        readOk = ReadShapefile(path, layer);
    }
    if(!readOk) {
        // Generate mock data based on filename pattern
        layer.crs = "EPSG:4326";
        layer.minX=0; layer.minY=0; layer.maxX=1; layer.maxY=1;
        if(path.find("road")!=std::string::npos) {
            layer.name="道路中心线"; layer.geomType=GEOM_LINESTRING;
            layer.fieldNames={"OBJECTID","ROAD_NAME"}; layer.fieldTypes={"int","string"};
            struct RD{int id;const char*nm;double p[6];};
            RD rds[]={{1,"迎宾大街",{0.12,0.48,0.35,0.48,0.88,0.48}},{2,"新建路",{0.58,0.16,0.58,0.35,0.58,0.86}},
                      {3,"安宁街",{0.22,0.22,0.40,0.30,0.70,0.30}},{4,"顺城街",{0.15,0.72,0.40,0.65,0.85,0.60}}};
            for(auto&rd:rds){Feat f;f.fid=rd.id;f.geom.type=GEOM_LINESTRING;
                for(int j=0;j<3;j++)f.geom.pts.push_back({rd.p[j*2],rd.p[j*2+1]});
                f.fields.push_back({"OBJECTID","int",std::to_string(rd.id)});
                f.fields.push_back({"ROAD_NAME","string",rd.nm});
                layer.features.push_back(f);}
        } else if(path.find("point")!=std::string::npos||path.find("check")!=std::string::npos) {
            layer.name="核查点位"; layer.geomType=GEOM_POINT;
            layer.fieldNames={"OBJECTID","POINT_NAME","RESULT"}; layer.fieldTypes={"int","string","string"};
            struct PD{int id;const char*nm;const char*rs;double x,y;};
            PD pds[]={{1,"CK-001","通过",0.25,0.35},{2,"CK-002","待复核",0.50,0.38},
                      {3,"CK-003","通过",0.72,0.46},{4,"CK-004","不通过",0.40,0.70},
                      {5,"CK-005","通过",0.65,0.55},{6,"CK-006","通过",0.82,0.25}};
            for(auto&pd:pds){Feat f;f.fid=pd.id;f.geom.type=GEOM_POINT;
                f.geom.pts.push_back({pd.x,pd.y});
                f.fields.push_back({"OBJECTID","int",std::to_string(pd.id)});
                f.fields.push_back({"POINT_NAME","string",pd.nm});
                f.fields.push_back({"RESULT","string",pd.rs});
                layer.features.push_back(f);}
        } else {
            layer.name="建设用地面"; layer.geomType=GEOM_POLYGON;
            layer.fieldNames={"OBJECTID","DLMC","QSXZ"}; layer.fieldTypes={"int","string","string"};
            struct LD{int id;const char*nm;const char*ow;double cx,cy,w,h;};
            LD lds[]={{1,"仓储用地","北田物流园",0.14,0.18,0.20,0.18},{2,"工业用地","晋中开发区管委会",0.38,0.29,0.22,0.21},
                      {3,"公共设施","榆次区住建局",0.08,0.55,0.16,0.14},{4,"居住用地","新城社区",0.62,0.12,0.18,0.20},
                      {5,"耕地保护","郭家堡乡",0.45,0.58,0.22,0.16},{6,"商业服务","汇通街道办",0.75,0.35,0.14,0.18}};
            for(auto&ld:lds){Feat f;f.fid=ld.id;f.geom.type=GEOM_POLYGON;
                Ring ring;ring.pts={{ld.cx,ld.cy},{ld.cx+ld.w,ld.cy},{ld.cx+ld.w,ld.cy+ld.h},{ld.cx,ld.cy+ld.h},{ld.cx,ld.cy}};
                f.geom.rings.push_back(ring);
                f.fields.push_back({"OBJECTID","int",std::to_string(ld.id)});
                f.fields.push_back({"DLMC","string",ld.nm});
                f.fields.push_back({"QSXZ","string",ld.ow});
                layer.features.push_back(f);}
        }
    }
    LayerHandle h = layer.handle;
    if(outLayerInfo) *outLayerInfo = Dup(BuildLayerJson(layer));
    if(outErrCode) *outErrCode = GIS_OK;
    g_layers[h] = layer;
    return h;
}

int32_t CloseLayer(LayerHandle h) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end()) return GIS_ERR_LAYER_NOT_FOUND;
    g_layers.erase(it); return GIS_OK;
}

const char *GetLayerInfo(LayerHandle h, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end()){if(outErrCode)*outErrCode=GIS_ERR_LAYER_NOT_FOUND;return nullptr;}
    if(outErrCode)*outErrCode=GIS_OK;
    return Dup(BuildLayerJson(it->second));
}

const char *ListVectorSublayers(const char *filePath, int32_t *outErrCode) {
    std::string path = filePath ? filePath : "";
    std::string name = path;
    size_t slash = name.find_last_of("/\\");
    if (slash != std::string::npos) name = name.substr(slash + 1);
    size_t dot = name.find_last_of('.');
    if (dot != std::string::npos) name = name.substr(0, dot);
    if(outErrCode)*outErrCode=path.empty()?GIS_ERR_INVALID_PARAM:GIS_OK;
    if(path.empty()) return Dup("{\"ok\":false,\"layers\":[]}");
    return Dup("{\"ok\":true,\"layers\":[{\"name\":\"" + Esc(name) +
        "\",\"uri\":\"" + Esc(path) + "\"}]}");
}

static bool GeomHitsEnvelope(const Geom &g, double mnx, double mny, double mxx, double mxy) {
    auto chk=[&](double x,double y){return x>=mnx&&x<=mxx&&y>=mny&&y<=mxy;};
    if(g.type==GEOM_POLYGON)for(auto&r:g.rings)for(auto&pt:r.pts)if(chk(pt.x,pt.y))return true;
    for(auto&pt:g.pts)if(chk(pt.x,pt.y))return true;
    return false;
}

const char *QueryFeatures(LayerHandle h, double mnx, double mny, double mxx, double mxy, int32_t limit,
                          int32_t offset, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end()){if(outErrCode)*outErrCode=GIS_ERR_LAYER_NOT_FOUND;return nullptr;}
    auto &L=it->second;
    std::string j="{\"layerId\":\"L"+std::to_string(h)+"\",\"features\":[";
    int cnt=0; int skipped=0; bool first=true; bool hasMore=false;
    for(auto&f:L.features){
        if(GeomHitsEnvelope(f.geom,mnx,mny,mxx,mxy)){
            if(skipped<offset){skipped++;continue;}
            if(limit>0&&cnt>=limit){hasMore=true;break;}
            if(!first)j+=","; j+=BuildFeatJson(f); first=false;
            cnt++;
        }
    }
    j+=hasMore ? "],\"hasMore\":true}" : "],\"hasMore\":false}";
    if(outErrCode)*outErrCode=GIS_OK;
    return Dup(j);
}

const char *GetFeature(LayerHandle h, int64_t fid, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end()){if(outErrCode)*outErrCode=GIS_ERR_LAYER_NOT_FOUND;return nullptr;}
    for(auto&f:it->second.features)if(f.fid==fid){if(outErrCode)*outErrCode=GIS_OK;return Dup(BuildFeatJson(f));}
    if(outErrCode)*outErrCode=GIS_ERR_FEATURE_NOT_FOUND;return nullptr;
}

static const char *EditSessionResult(bool ok, int32_t code, const std::string &message,
                                     const Layer *layer, int32_t *outErrCode) {
    if(outErrCode)*outErrCode=ok?GIS_OK:code;
    size_t featureCount=layer?layer->features.size():0;
    std::string j="{\"ok\":"+std::string(ok?"true":"false")+",\"code\":"+std::to_string(code);
    j+=",\"message\":\""+Esc(message)+"\",\"outputPath\":\"\",\"outputLayerName\":\"\"";
    j+=",\"featureCount\":"+std::to_string(featureCount)+"}";
    return Dup(j);
}

const char *BeginEditSession(LayerHandle h, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end())return EditSessionResult(false,GIS_ERR_LAYER_NOT_FOUND,"Layer not found",nullptr,outErrCode);
    it->second.editSessionActive=true;
    return EditSessionResult(true,GIS_OK,"Edit session started",&it->second,outErrCode);
}

const char *CommitEditSession(LayerHandle h, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end())return EditSessionResult(false,GIS_ERR_LAYER_NOT_FOUND,"Layer not found",nullptr,outErrCode);
    if(!it->second.editSessionActive)return EditSessionResult(false,GIS_ERR_INVALID_PARAM,"No active edit session",&it->second,outErrCode);
    it->second.editSessionActive=false;
    return EditSessionResult(true,GIS_OK,"Edit session committed",&it->second,outErrCode);
}

const char *RollbackEditSession(LayerHandle h, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end())return EditSessionResult(false,GIS_ERR_LAYER_NOT_FOUND,"Layer not found",nullptr,outErrCode);
    if(!it->second.editSessionActive)return EditSessionResult(false,GIS_ERR_INVALID_PARAM,"No active edit session",&it->second,outErrCode);
    it->second.editSessionActive=false;
    return EditSessionResult(true,GIS_OK,"Edit session rolled back",&it->second,outErrCode);
}

const char *UndoEdit(LayerHandle h, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end())return EditSessionResult(false,GIS_ERR_LAYER_NOT_FOUND,"Layer not found",nullptr,outErrCode);
    return EditSessionResult(false,GIS_ERR_NATIVE_NOT_READY,"Undo requires the QGIS edit backend",&it->second,outErrCode);
}

const char *RedoEdit(LayerHandle h, int32_t *outErrCode) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    if(it==g_layers.end())return EditSessionResult(false,GIS_ERR_LAYER_NOT_FOUND,"Layer not found",nullptr,outErrCode);
    return EditSessionResult(false,GIS_ERR_NATIVE_NOT_READY,"Redo requires the QGIS edit backend",&it->second,outErrCode);
}

bool IsEditing(LayerHandle h) {
    std::lock_guard<std::mutex> lk(g_mutex);
    auto it=g_layers.find(h);
    return it!=g_layers.end()&&it->second.editSessionActive;
}

bool HasPendingEdits(LayerHandle h) {(void)h;return false;}
bool CanUndo(LayerHandle h) {(void)h;return false;}
bool CanRedo(LayerHandle h) {(void)h;return false;}

static const char *MockProcessResult(const char *outputPath, const char *outputLayerName, int32_t *outErrCode) {
    if(outErrCode)*outErrCode=GIS_ERR_NATIVE_NOT_READY;
    std::string j="{\"ok\":false,\"code\":"+std::to_string(GIS_ERR_NATIVE_NOT_READY);
    j+=",\"message\":\"GDAL backend is required for geoprocessing\"";
    j+=",\"outputPath\":\""+Esc(outputPath?outputPath:"")+"\"";
    j+=",\"outputLayerName\":\""+Esc(outputLayerName?outputLayerName:"")+"\"";
    j+=",\"featureCount\":0}";
    return Dup(j);
}

const char *BufferLayer(LayerHandle h, double distance, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode) {
    (void)h; (void)distance;
    return MockProcessResult(outputPath, outputLayerName, outErrCode);
}

const char *RepairLayer(LayerHandle h, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode) {
    (void)h;
    return MockProcessResult(outputPath, outputLayerName, outErrCode);
}

const char *ClipLayer(LayerHandle inputHandle, LayerHandle clipHandle, const char *outputPath,
                      const char *outputLayerName, int32_t *outErrCode) {
    (void)inputHandle; (void)clipHandle;
    return MockProcessResult(outputPath, outputLayerName, outErrCode);
}

const char *ExportLayer(LayerHandle h, const char *outputPath,
                        const char *outputLayerName, int32_t *outErrCode) {
    (void)h;
    return MockProcessResult(outputPath, outputLayerName, outErrCode);
}

const char *ExportLayerToFormat(LayerHandle h, const char *outputPath,
                                const char *outputLayerName, const char *driverName,
                                int32_t *outErrCode) {
    (void)h; (void)driverName;
    return MockProcessResult(outputPath, outputLayerName, outErrCode);
}

const char *DefineLayerProjection(LayerHandle h, const char *targetDefinition, const char *outputPath,
                                  const char *outputLayerName, int32_t *outErrCode) {
    (void)h; (void)targetDefinition;
    return MockProcessResult(outputPath, outputLayerName, outErrCode);
}

const char *ProjectLayer(LayerHandle h, const char *targetDefinition, const char *outputPath,
                         const char *outputLayerName, int32_t *outErrCode) {
    (void)h; (void)targetDefinition;
    return MockProcessResult(outputPath, outputLayerName, outErrCode);
}

const char *GetProcessingAlgorithms() {
    return Dup("{\"backend\":\"stub\",\"algorithms\":[]}");
}

const char *ExecuteProcessingAlgorithm(const char *requestJson, int32_t *outErrCode) {
    (void)requestJson;
    return MockProcessResult("", "", outErrCode);
}

PreparedProcessingTask *PrepareProcessingTask(const char *requestJson, char **outErrorMessage,
                                               int32_t *outErrCode) {
    (void)requestJson;
    if (outErrorMessage) *outErrorMessage = Dup("Background Processing requires the QGIS backend");
    if (outErrCode) *outErrCode = GIS_ERR_NATIVE_NOT_READY;
    return nullptr;
}

const char *RunPreparedProcessingTask(PreparedProcessingTask *task,
                                      const ProcessingCallbacks *callbacks,
                                      int32_t *outErrCode) {
    (void)task; (void)callbacks;
    return MockProcessResult("", "", outErrCode);
}

void FreePreparedProcessingTask(PreparedProcessingTask *task) { delete task; }

const char *ReadQgisProject(const char *projectPath, int32_t *outErrCode) {
    return MockProcessResult(projectPath, "", outErrCode);
}

const char *WriteQgisProject(const char *projectPath, const char *projectName,
                             const char *projectCrs, const char *layerHandles,
                             int32_t *outErrCode) {
    (void)projectName; (void)projectCrs; (void)layerHandles;
    return MockProcessResult(projectPath, "", outErrCode);
}

const char *ExtractZipArchive(const char *zipPath, const char *outputDirectory, int32_t *outErrCode) {
    (void)zipPath;
    return MockProcessResult(outputDirectory, "", outErrCode);
}

void FreeCString(char *s){if(s)free(s);}

} // namespace geonest
