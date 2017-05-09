//
//  TenPointAveraging.metal
//  Mosaix
//
//  Created by Nathan Eliason on 4/19/17.
//  Copyright © 2017 Nathan Eliason. All rights reserved.
//
//

#include <metal_stdlib>
using namespace metal;


// Thread ID == (thread position in thread group) + (thread group position in grid * threads per thread group)

// Each threadgroup handles a different section of the image.

kernel void findNinePointAverage(
    texture2d<float, access::read> image [[ texture(0) ]],
    device uint* result [[ buffer(0) ]],
    uint threadId [[ thread_position_in_threadgroup ]],
    uint threadsInGroup [[ threads_per_threadgroup ]],
    uint threadGroupId [[ threadgroup_position_in_grid ]]
) {
    threadgroup atomic_uint red;
    threadgroup atomic_uint green;
    threadgroup atomic_uint blue;
    
    if (threadId == 0) {
        atomic_store_explicit(&red, 0, memory_order_relaxed);
        atomic_store_explicit(&green, 0, memory_order_relaxed);
        atomic_store_explicit(&blue, 0, memory_order_relaxed);
    }
    
    threadgroup_barrier(mem_flags::mem_device);
    
    const int squaresInRow = 3;
    const int imageWidth = image.get_width();
    const int imageHeight = image.get_height();
    
    
    uint squareHeight = imageHeight / squaresInRow;
    uint squareWidth = imageWidth / squaresInRow;
    
    uint squareIndex = threadGroupId;
    if (squareIndex < squaresInRow * squaresInRow) {
        float4 sum = float4(0.0, 0.0, 0.0, 0.0);
        int numRows = 0;
        for (uint row = threadId; row < squareHeight; row += threadsInGroup) {
            numRows++;
            uint squareRow = (squareIndex / squaresInRow);
            uint squareCol = squareIndex % squaresInRow;
            
            uint pixelRow = squareRow * squareHeight;
            
            //Now, process that row of the square.
            for (uint delta = 0; delta < squareWidth; delta++) {
                uint2 coord = uint2(pixelRow, squareCol*squareWidth + delta);
                float4 colorAtIndex = image.read(coord);
                sum += colorAtIndex;
            }
        }
        threadgroup_barrier(mem_flags::mem_device);
        if (numRows > 0) {
            sum.r = sum.r * 255 / (numRows * squareWidth);
            sum.g = sum.g * 255 / (numRows * squareWidth);
            sum.b = sum.b * 255 / (numRows * squareWidth);
        
            atomic_fetch_add_explicit(&red, int(sum.r), memory_order_relaxed);
            atomic_fetch_add_explicit(&green, int(sum.g), memory_order_relaxed);
            atomic_fetch_add_explicit(&blue, int(sum.b), memory_order_relaxed);
        }
        threadgroup_barrier(mem_flags::mem_device);
        
        int numWorkers = min(threadsInGroup, squareHeight);
        
        if (threadId == 0) {
            result[squareIndex * 3 + 0] = uint(atomic_load_explicit(&red, memory_order_relaxed) / numWorkers);
            result[squareIndex * 3 + 1] = uint(atomic_load_explicit(&green, memory_order_relaxed) / numWorkers);
            result[squareIndex * 3 + 2] = uint(atomic_load_explicit(&blue, memory_order_relaxed) / numWorkers);
        }
    }
}

kernel void findPhotoNinePointAverage(
     texture2d<float, access::read> image [[ texture(0) ]],
     device uint* params [[ buffer(0) ]],
     device uint* result [[ buffer(1) ]],
     uint threadId [[ thread_position_in_grid ]],
     uint numThreads [[ threads_per_grid ]]
) {
    
    const int imageWidth = image.get_width();
    const int imageHeight = image.get_height();
    
    const uint gridSize = params[0];
    
    uint gridSquaresInRow = imageWidth / gridSize;
    uint gridSquaresInCol = imageHeight / gridSize;
    
    // The total number of nine-point squares in the entire photo
    uint ninePointSquares = gridSquaresInRow * gridSquaresInCol * 9;
    
    for (uint squareIndex = threadId; squareIndex < ninePointSquares; squareIndex += numThreads) {
        float4 sum = float4(0.0, 0.0, 0.0, 0.0);
        
        uint gridSquareIndex = squareIndex / 9;
        uint gridSquareX = (gridSquareIndex % gridSquaresInRow) * gridSize;
        uint gridSquareY = (gridSquareIndex / gridSquaresInRow) * gridSize;
        
        uint ninePointIndex = squareIndex % 9;
        uint ninePointSize = gridSize / 3;
        uint ninePointX = gridSquareX + (( ninePointIndex % 3) * ninePointSize);
        uint ninePointY = gridSquareY + (( ninePointIndex / 3) * ninePointSize);
        
        for (uint deltaY = 0; deltaY < ninePointSize; deltaY++) {
            for (uint deltaX = 0; deltaX < ninePointSize; deltaX++) {
                uint2 coord = uint2(ninePointX + deltaX, ninePointY + deltaY);
                sum += image.read(coord);
            }
        }
        sum.r = sum.r * 255 / (ninePointSize * ninePointSize);
        sum.g = sum.g * 255 / (ninePointSize * ninePointSize);
        sum.b = sum.b * 255 / (ninePointSize * ninePointSize);
        
        result[squareIndex * 3 + 0] = uint(sum.r);
        result[squareIndex * 3 + 1] = uint(sum.g);
        result[squareIndex * 3 + 2] = uint(sum.b);
    }
}

kernel void findNearestMatches(

) {
    
}

