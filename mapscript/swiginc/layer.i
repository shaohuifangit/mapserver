/* ===========================================================================
   $Id$
 
   Project:  MapServer
   Purpose:  SWIG interface file for mapscript layerObj extensions
   Author:   Steve Lime 
             Sean Gillies, sgillies@frii.com
             
   ===========================================================================
   Copyright (c) 1996-2001 Regents of the University of Minnesota.
   
   Permission is hereby granted, free of charge, to any person obtaining a
   copy of this software and associated documentation files (the "Software"),
   to deal in the Software without restriction, including without limitation
   the rights to use, copy, modify, merge, publish, distribute, sublicense,
   and/or sell copies of the Software, and to permit persons to whom the
   Software is furnished to do so, subject to the following conditions:
 
   The above copyright notice and this permission notice shall be included
   in all copies or substantial portions of the Software.
 
   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
   THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.
   ===========================================================================
*/

%extend layerObj 
{

    layerObj(mapObj *map=NULL) 
    {
        layerObj *layer;
        int result;
        
        if (!map) {
            layer = (layerObj *) malloc(sizeof(layerObj));
            if (!layer) {
                msSetError(MS_MEMERR, "Failed to initialize Layer",
                                       "layerObj()");
                return NULL;
            } 
            result = initLayer(layer, NULL);
            if (result == MS_SUCCESS) {
                return layer;
            }
            else {
                msSetError(MS_MEMERR, "Failed to initialize Layer",
                                       "layerObj()");
                return NULL;
            }
        }
        else { // parent map exists
            if (map->numlayers == MS_MAXLAYERS) { // no room
                msSetError(MS_CHILDERR, "Max number of layers exceeded",
                                        "layerObj()");
                return(NULL);
            }

            if (initLayer(&(map->layers[map->numlayers]), map) == -1)
                return(NULL);

            map->layers[map->numlayers].index = map->numlayers;
            map->layerorder[map->numlayers] = map->numlayers;
            map->numlayers++;

            return &(map->layers[map->numlayers-1]);
        }
    }

    ~layerObj() 
    {
        if (!self->map) {
            freeLayer(self);
            //free(self);
        }
        // else map deconstructor takes care of it
    }

    /* removeClass() */
    void removeClass(int index) 
    {
        int i;
        for (i = index + 1; i < self->numclasses; i++) {
#ifndef __cplusplus
            self->class[i-1] = self->class[i];
#else
            self->_class[i-1] = self->_class[i];
#endif
        }
        self->numclasses--;
    }

    int open() 
    {
        int status;
        status =  msLayerOpen(self);
        if (status == MS_SUCCESS) {
            return msLayerGetItems(self);
        }
        return status;
    }

    void close() 
    {
        msLayerClose(self);
    }

#ifdef NEXT_GENERATION_API
    %newobject getShape;
    shapeObj *getShape(int shapeindex, int tileindex=0) 
    {
    /* This version properly returns shapeObj and also has its
     * arguments properly ordered so that users can ignore the
     * tileindex if they are not accessing a tileindexed layer.
     * See bug 586:
     * http://mapserver.gis.umn.edu/bugs/show_bug.cgi?id=586 */
        int retval;
        shapeObj *shape;
        shape = (shapeObj *)malloc(sizeof(shapeObj));
        if (!shape)
            return NULL;
        msInitShape(shape);
        shape->type = self->type;
        retval = msLayerGetShape(self, shape, tileindex, shapeindex);
        return shape;
    }
#else
    int getShape(shapeObj *shape, int tileindex, int shapeindex) 
    {
        return msLayerGetShape(self, shape, tileindex, shapeindex);
    }
#endif
  
    int getNumResults() 
    {
        if (!self->resultcache) return 0;
        return self->resultcache->numresults;
    }

    resultCacheMemberObj *getResult(int i) 
    {
        if (!self->resultcache) return NULL;
        if (i >= 0 && i < self->resultcache->numresults)
            return &self->resultcache->results[i]; 
        else
            return NULL;
    }

    classObj *getClass(int i) 
    { // returns an EXISTING class

        if (i >= 0 && i < self->numclasses)
            return &(self->class[i]); 
        else
            return NULL;
    }

    char *getItem(int i) 
    { // returns an EXISTING item
  
        if (i >= 0 && i < self->numitems)
            return (char *) (self->items[i]);
        else
            return NULL;
    }

    int draw(mapObj *map, imageObj *image) 
    {
        return msDrawLayer(map, self, image);    
    }

    int drawQuery(mapObj *map, imageObj *image) 
    {
        return msDrawQueryLayer(map, self, image);    
    }

    int queryByAttributes(mapObj *map, char *qitem, char *qstring, int mode) 
    {
        return msQueryByAttributes(map, self->index, qitem, qstring, mode);
    }

    int queryByPoint(mapObj *map, pointObj *point, int mode, double buffer) 
    {
        return msQueryByPoint(map, self->index, mode, *point, buffer);
    }

    int queryByRect(mapObj *map, rectObj rect) 
    {
        return msQueryByRect(map, self->index, rect);
    }

    int queryByFeatures(mapObj *map, int slayer) 
    {
        return msQueryByFeatures(map, self->index, slayer);
    }

    int queryByShape(mapObj *map, shapeObj *shape) 
    {
        return msQueryByShape(map, self->index, shape);
    }

    int setFilter(char *string) 
    {
        if (!string || strlen(string) == 0) {
            freeExpression(&self->filter);
            return MS_SUCCESS;
        }
        else return loadExpressionString(&self->filter, string);
    }

    %newobject getFilterString;
    char *getFilterString() 
    {
        char exprstring[256];
        switch (self->filter.type) {
            case (MS_REGEX):
                snprintf(exprstring, 255, "/%s/", self->filter.string);
                return strdup(exprstring);
            case (MS_STRING):
                snprintf(exprstring, 255, "\"%s\"", self->filter.string);
                return strdup(exprstring);
            case (MS_EXPRESSION):
                snprintf(exprstring, 255, "(%s)", self->filter.string);
                return strdup(exprstring);
        }
        return NULL;
    }

    int setWKTProjection(char *string) 
    {
        self->project = MS_TRUE;
        return msOGCWKT2ProjectionObj(string, &(self->projection), self->debug);
    }

    %newobject getProjection;
    char *getProjection() 
    {    
        return (char *) msGetProjectionString(&(self->projection));
    }

    int setProjection(char *string) 
    {
        self->project = MS_TRUE;
        return msLoadProjectionString(&(self->projection), string);
    }

    int addFeature(shapeObj *shape) 
    {    
        self->connectiontype = MS_INLINE; // set explicitly
        if (insertFeatureList(&(self->features), shape) == NULL) 
        return MS_FAILURE;
        return MS_SUCCESS;
    }

    /*
    Returns the number of inline feature of a layer
    */
    int getNumFeatures() 
    {
        return msLayerGetNumFeatures(self);
    }

    %newobject getExtent;
    rectObj *getExtent() 
    {
        rectObj *extent;
        extent = (rectObj *) malloc(sizeof(rectObj));
        msLayerOpen(self);
        msLayerGetExtent(self, extent);
        msLayerClose(self);
        return extent;
    }

    /* 
    The following metadata methods are no longer needed since we have
    promoted the metadata member of layerObj to a first-class mapscript
    object.  See hashtable.i.  Not yet scheduled for deprecation but 
    perhaps in the next major release?  --SG
    */ 
    char *getMetaData(char *name) 
    {
        char *value = NULL;
        if (!name) {
            msSetError(MS_HASHERR, "NULL key", "getMetaData");
        }
     
        value = (char *) msLookupHashTable(&(self->metadata), name);
        if (!value) {
            msSetError(MS_HASHERR, "Key %s does not exist", "getMetaData", name);
            return NULL;
        }
        return value;
    }

    int setMetaData(char *name, char *value) 
    {
        if (msInsertHashTable(&(self->metadata), name, value) == NULL)
        return MS_FAILURE;
        return MS_SUCCESS;
    }

    int removeMetaData(char *name) 
    {
        return(msRemoveHashTable(&(self->metadata), name));
    }

    char *getFirstMetaDataKey() 
    {
        return (char *) msFirstKeyFromHashTable(&(self->metadata));
    }
 
    char *getNextMetaDataKey(char *lastkey) 
    {
        return (char *) msNextKeyFromHashTable(&(self->metadata), lastkey);
    }
  
    %newobject getWMSFeatureInfoURL;
    char *getWMSFeatureInfoURL(mapObj *map, int click_x, int click_y,
                               int feature_count, char *info_format)
    {
        return (char *) msWMSGetFeatureInfoURL(map, self, click_x, click_y,
               feature_count, info_format);
    }
 
    %newobject executeWFSGetFeature;
    char *executeWFSGetFeature(layerObj *layer) 
    {
        return (char *) msWFSExecuteGetFeature(layer);
    }

    int applySLD(char *sld, char *stylelayer) 
    {
        return msSLDApplySLD(self->map, sld, self->index, stylelayer);
    }

    int applySLDURL(char *sld, char *stylelayer) 
    {
        return msSLDApplySLDURL(self->map, sld, self->index, stylelayer);
    }

    %newobject generateSLD; 
    char *generateSLD() 
    {
        return (char *) msSLDGenerateSLD(self->map, self->index);
    }

    int moveClassUp(int index) 
    {
        return msMoveClassUp(self, index);
    }

    int moveClassDown(int index) 
    {
        return msMoveClassDown(self, index);
    }

    void setProcessingKey(const char *key, const char *value) 
    {
	   msLayerSetProcessingKey( self, key, value );
    }
 
    /* this method is deprecated ... should use addProcessing() */
    void setProcessing(const char *directive ) 
    {
        msLayerAddProcessing( self, directive );
    }

    void addProcessing(const char *directive ) 
    {
        msLayerAddProcessing( self, directive );
    }

    char *getProcessing(int index) 
    {
        return (char *) msLayerGetProcessing(self, index);
    }

    int clearProcessing() 
    {
        return msLayerClearProcessing(self);
    }

}
